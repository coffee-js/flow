interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '



class DebugContex
  constructor: (parent, @block, @nextCallback=null, @intoCallback=null) ->
    if parent == null
      @blockStack = [@block]
    else
      @blockStack = parent.blockStack.concat [@block]
    @pElemIdx = 0

  into: (b) ->
    if @intoCallback != null
      @intoCallback @, b
    new DebugContex @, b, @nextCallback, @intoCallback

  next: ->
    @pElemIdx += 1
    if @nextCallback != null
      @nextCallback @, @pElemIdx
    @

  pElem: ->
    e = @block.seq[@pElemIdx-1]
    e


err = (txt, ctx, srcInfo) ->
  ctxInfo = ""
  if ctx != null && ctx.debug != null
    a = []
    for b in ctx.debug.blockStack
      a.unshift "from #{b.srcInfo.toStr()}"
    ctxInfo = a.join "\n"
  if srcInfo != null
    s = "#{srcInfo.toStr()} #{txt}\n#{ctxInfo}"
  else
    s = "#{txt}\n#{ctxInfo}"
  throw s


class BuildinWord
  constructor: (@argCount, @fn) ->

  eval: (ctx) ->
    retSeq = ctx.retSeq
    if ctx.debug
      srcInfo = ctx.debug.pElem().srcInfo
    else
      srcInfo = null
    args = retSeq.slice -@argCount
    if args.length < @argCount
      err "no enough args in seq:#{retSeq}", ctx, srcInfo
    retSeq.length = retSeq.length-@argCount
    args = [ctx].concat args
    @fn args...


bw = ->
  new BuildinWord arguments...

ct = (ctx, e, ta...) ->
  for t in ta
    if typeof(e.val) == t
      pass = true
  if !pass
    ts = ta.join " or "
    err "expect a #{ts}, got:[#{e.toStr()}:#{typeof(e.val)}]", ctx, e.srcInfo

ct2 = (ctx, a, b, t) ->
  ct ctx, a, t; ct ctx, b, t

ck = (ctx, e, ka...) ->
  ct ctx, e, "object"
  for k in ka
    if e.val instanceof k
      pass = true
  if !pass
    ks = ka.join " or "
    err "expect a #{ks}: #{e.toStr()}", ctx, e.srcInfo


buildinWords = {
  "+":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val+b.val
  "-":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val-b.val
  "*":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val*b.val
  "/":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val/b.val
  "%":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val%b.val
  "neg":  bw 1, (ctx, a)    -> ct  ctx, a,    "number"; -a.val
  "abs":  bw 1, (ctx, a)    -> ct  ctx, a,    "number"; Math.abs a.val

  "=":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val==b.val
  "<":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val<b.val
  ">":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val>b.val
  "<=":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val<=b.val
  ">=":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a.val>=b.val

  "not":  bw 1, (ctx, a)    -> ct  ctx, a,    "boolean"; !a.val
  "and":  bw 2, (ctx, a, b) -> ct2 ctx, a, b, "boolean"; a.val&&b.val
  "or":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "boolean"; a.val||b.val

  "if":   bw 3, (ctx, cond, whenTrue, whenFals) ->
    ct ctx, cond, 'boolean'
    ck ctx, whenTrue, Closure
    ck ctx, whenFals, Closure

    if cond.val
      seqApplyEval whenTrue.val, ctx
    else
      seqApplyEval whenFals.val, ctx
    undefined

  "apply": bw 1, (ctx, elem) ->
    ck ctx, elem, Closure
    c = elem.val
    seqApply c, ctx

  "eval": bw 1, (ctx, elem) ->
    ck ctx, elem, Closure
    c = elem.val
    seqApplyEval c, ctx
    undefined

  "get":  bw 2, (ctx, cElem, nameElem) ->
    ck ctx, cElem, Closure
    ct ctx, nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    [found, elem] = c.getElem name, ctx
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{c.toStr()}", ctx, nameElem.srcInfo

  "set":  bw 3, (ctx, cElem, elem, nameElem) ->
    ck ctx, cElem, Closure
    ct ctx, nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    c.setElem name, elem

  "len":  bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.len()

  "count-arg-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.argWordCount

  "count-non-arg-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.nonArgWordCount()

  "count-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.wordCount()

  "count-arg-slots": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.argSlotCount()

  "count": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.count()

  "slice": bw 3, (ctx, cElem, start, end) ->
    ck ctx, cElem, Closure
    ct ctx, start, "number"
    ct ctx, end, "number"

    c = cElem.val
    c.slice start.val, end.val

  "join": bw 2, (ctx, a, b) ->
    ck ctx, a, Closure
    ck ctx, b, Closure
    a.val.join b.val

  "splice": bw 4, (ctx, cElem, iElem, delCountElem, addElemsCElem) ->
    ck ctx, cElem, Closure
    ct ctx, iElem, "number"
    ct ctx, delCountElem, "number"
    ck ctx, addElemsCElem, Closure

    c = cElem.val
    c.splice iElem.val, delCountElem.val, addElemsCElem.val.seq(ctx)

  "curry": bw 2, (ctx, cElem, nElem) ->
    ck ctx, cElem, Closure
    ct ctx, nElem, "number"

    c = cElem.val
    n = nElem.val
    if n > c.args.length
      argN = c.args.length
      seqN = n - c.args.length
    else
      argN = n
    argWords = curryArgWords c, ctx, argN
    r = c.apply argWords
    if seqN != undefined
      retSeq = ctx.retSeq
      unshifts = retSeq.slice -seqN
      retSeq.length = retSeq.length-seqN
      r = r.splice 1, 0, unshifts
    r

  "wapply": bw 2, (ctx, wElem, cElem) ->
    ck ctx, wElem, Closure
    ck ctx, cElem, Closure

    w = wElem.val
    c = cElem.val
    w.wordEnvInit()
    argWords = w.words
    c.apply argWords

  "filter-arg-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.filterArgWords()

  "filter-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.filterWords()

  "filter-non-arg-words": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.filterNonArgWords()

  "filter-seq": bw 1, (ctx, cElem) ->
    ck ctx, cElem, Closure
    c = cElem.val
    c.filterSeq()

  # "map"
  # "filter"
  # "fold"
}


sepWordNameProc = (name) ->
  opt = {}
  switch name[0]
    when "'"
      opt.notEval = true
      name = name.slice 1
  [name, opt]


wordInEnv = (name, wordEnv) ->
  for words in wordEnv
    e = words[name]
    if e != undefined
      if e.val instanceof Word
        return wordInEnv e.val.name, e.val.wordEnv
      else
        return e.val
  null

wordVal = (name, wordEnv, ctx) ->
  [name, opt] = sepWordNameProc name
  v = wordInEnv(name, wordEnv)
  if v == null
    v = buildinWords[name]
  else if opt.notEval
    v = v.valDup ctx
  v


curryArgWords = (c, ctx, n) ->
  retSeq = ctx.retSeq
  if ctx.debug
    srcInfo = ctx.debug.pElem().srcInfo
  else
    srcInfo = null
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c.toStr()} args count:#{c.args.length} < #{n}", ctx, srcInfo
  argWords = {}
  if retSeq.length < n
    err "no enough elems in seq, seq.len:#{retSeq.length} n:#{n}", ctx, srcInfo
  args = retSeq.slice -n
  for i in [0..n-1]
    a = c.args[i]
    w = args[i]
    argWords[a.name] = w
  retSeq.length = retSeq.length-n
  argWords


seqApply = (c, ctx) ->
  if c.args.length > 0
    argWords = curryArgWords c, ctx, c.args.length
    c.apply argWords
  else
    c


class Context
  constructor: ->
    @retSeq = []
    @debug = null

  into: (b) ->
    if @debug == null
      @
    else
      c = new Context
      c.retSeq = @retSeq
      c.debug = @debug.into b
      c

  next: ->
    if @debug == null
      @
    else
      @debug = @debug.next()
      @


seqApplyEval = (c, ctx) ->
  (seqApply c, ctx).eval ctx


seqEval = (val, ctx, wordEnv) ->
  if      val instanceof Closure && val.elemType == "EVAL"
    seqApplyEval val, ctx
  else if val instanceof BuildinWord
    v = val.eval ctx
    if v != undefined
      seqEval v, ctx, wordEnv
  else
    if ctx.debug
      srcInfo = ctx.debug.pElem().srcInfo
    else
      srcInfo = null
    ctx.retSeq.push new ast.Elem val, srcInfo


class Word
  constructor: (@name, @wordEnv) ->


class Closure
  constructor: (@block, @preWordEnv, argWords=null) ->
    @elemType = @block.elemType
    @words = {}
    @argWords = {}
    @argWordCount = 0
    if argWords
      @args = []
      for a in @block.args
        if argWords[a.name] == undefined
          @args.push a
        else
          @words[a.name] = @argWords[a.name] = argWords[a.name]
          @argWordCount += 1
    else
      @args = @block.args

  valDup: (ctx) ->
    switch @elemType
      when "EVAL"
        c = new Closure @block, @preWordEnv, @argWords
        c.elemType = "VAL"
        c
      when "VAL"
        @
      else
        err "fatal error: #{@toStr()} @elemType:#{@elemType}", ctx, null

  wordEnvInit: ->
    if @wordEnv != undefined
      return
    @wordEnv = [@words].concat @preWordEnv
    for name of @block.words
      e = @block.words[name]
      if e == null
        continue
      if      e.val instanceof ast.Word
        v = new Word e.val.name, @wordEnv
      else if e.val instanceof ast.Block
        v = new Closure e.val, @wordEnv
      else
        v = e.val
      e = new ast.Elem v, name, e.srcInfo
      @words[name] = e

  elemEval: (e, ctx) ->
    @wordEnvInit()
    if      e.val instanceof ast.Word
      v = wordVal e.val.name, @wordEnv, ctx
      if v == undefined
        err "word:#{e.val.name} not defined", ctx, e.srcInfo
    else if e.val instanceof ast.Block
      args = []
      for a in @block.args
        if @argWords[a.name] == undefined
          args.push a
      b = e.val.addArgs args
      v = new Closure b, @wordEnv
    else
      v = e.val
    v

  eval: (ctx) ->
    ctx = ctx.into @block
    for e in @block.seq
      ctx = ctx.next()
      seqEval @elemEval(e, ctx), ctx, @wordEnv


  apply: (argWords) ->
    aw = {}
    for a in @block.args
      if @argWords[a.name] != undefined
        aw[a.name] = @argWords[a.name]
      if argWords[a.name] != undefined
        aw[a.name] = argWords[a.name]
    new Closure @block, @preWordEnv, aw

  seq: (ctx) ->
    if @_seq != undefined
      return @_seq
    @_seq = []
    for e in @block.seq
      @_seq.push new ast.Elem @elemEval(e, ctx), e.srcInfo
    @_seq

  getElem: (name, ctx) ->
    [name, opt] = sepWordNameProc name
    [found, e] = @block.getElem name
    if found
      if e != null
        e = new ast.Elem @elemEval(e, ctx), e.srcInfo
      else if @argWords[name] != undefined
        e = @argWords[name]
      else
        found = false
    if found && e.val instanceof Closure && opt.notEval
      e.val = e.val.valDup ctx
    [found, e]

  setElem: (name, elem) ->
    if @block.argWords[name] != undefined
      aw = {}
      for a in @block.args
        if @argWords[a.name] != undefined
          aw[a.name] = @argWords[a.name]
      aw[name] = elem
      new Closure @block, @preWordEnv, aw
    else
      b = @block.setElem name, elem
      new Closure b, @preWordEnv, @argWords

  len: -> @block.len()
  nonArgWordCount: -> @block.nonArgWordCount()
  wordCount: -> @nonArgWordCount() + @argWordCount
  argSlotCount: -> @block.args.length
  count: -> @len() + @wordCount()

  slice: (p1, p2) ->
    b = @block.slice p1, p2
    new Closure b, @preWordEnv, @argWords

  join: (other) ->
    b = @block.join other.block
    aw = {}
    for name of @argWords
      aw[name] = @argWords[name]
    for name of other.argWords
      aw[name] = other.argWords[name]
    new Closure b, @preWordEnv, aw

  splice: (i, delCount, addElems) ->
    b = @block.splice i, delCount, addElems
    new Closure b, @preWordEnv, @argWords

  filterArgWords: ->
    b = @block.filterArgWords()
    new Closure b, @preWordEnv, @argWords

  filterWords: ->
    b = @block.filterWords()
    new Closure b, @preWordEnv, @argWords

  filterNonArgWords: ->
    b = @block.filterNonArgWords()
    new Closure b, @preWordEnv, {}

  filterSeq: ->
    b = @block.filterSeq()
    new Closure b, @preWordEnv, {}

  toStr: ->
    @block.toStr()



interp.eval = (blockElem) ->
  b = blockElem.val
  ctx = new Context
  ctx.debug = new DebugContex null, b
  c = new Closure b, []
  c.eval ctx
  ctx.retSeq













