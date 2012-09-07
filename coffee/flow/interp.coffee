interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, "  "



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
    ct ctx, cond, "boolean"
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

  "do": bw 1, (ctx, elem) ->
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
    c.setElem name, elem, ctx

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

  "concat": bw 2, (ctx, a, b) ->
    ck ctx, a, Closure
    ck ctx, b, Closure
    a.val.concat b.val

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
  opt = null
  switch name[0]
    when "'", "!"
      opt = name[0]
      name = name.slice 1
  [name, opt]


wordInEnv = (name, wordEnv, ctx) ->
  for words in wordEnv
    e = words[name]
    if e != undefined
      if e.val instanceof Word
        return wordVal e.val, e.val.wordEnv, ctx
      else
        return e.val
  null

wordVal = (word, wordEnv, ctx) ->
  if ctx.debug
    srcInfo = ctx.debug.pElem().srcInfo
  else
    srcInfo = null

  if word.entry != null
    name = word.entry
    v = wordInEnv name, wordEnv, ctx
    if v == null && word.refines.length == 0
      v = buildinWords[name]
    else
      curPath = [name]
  else
    if ctx.retSeq.length == 0
      err "no enough args in seq:#{ctx.retSeq}", ctx, srcInfo
    cElem = ctx.retSeq.pop()
    ck ctx, cElem, Closure
    v = cElem.val
    curPath = [null]

  if word.opt != null && word.opt[0] == "#"
    refines = word.refines.slice 0,-1
  else
    refines = word.refines
  for name in refines
    curPath.push name
    if !(v instanceof Closure)
      err "path:#{curPath.join(".")} can not reach", ctx, srcInfo
    [found, e] = v.getElem name, ctx
    if !found
      err "word:#{name} not defined in path:#{curPath.slice(0,-1).join(".")}", ctx, srcInfo
    v = e.val
  if word.opt == "'"
    if !(v instanceof Closure)
      err "word:#{word.name} is not a block", ctx, srcInfo
    v = v.valDup ctx
  else if word.opt != null && word.opt[0] == "#"
    if ctx.retSeq.length == 0
      err "no enough args in seq:#{ctx.retSeq}", ctx, srcInfo
    elem = ctx.retSeq.pop()
    name = word.refines[refines.length]
    if word.opt == "#!"
      name = "!#{name}"
    v = v.setElem name, elem, ctx
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
    name = c.args[i]
    w = args[i]
    argWords[name] = w
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
  constructor: (w, @wordEnv) ->
    @entry = w.entry
    @refines = w.refines
    @name = w.name
    @opt = w.opt


class Closure
  constructor: (@block, @preWordEnv, argWords=null) ->
    @elemType = @block.elemType
    @words = {}
    @argWords = {}
    @argWordCount = 0
    if argWords
      @args = []
      for name in @block.args
        if argWords[name] == undefined
          @args.push name
        else
          @words[name] = @argWords[name] = argWords[name]
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

  evalDup: (ctx) ->
    switch @elemType
      when "EVAL"
        @
      when "VAL"
        c = new Closure @block, @preWordEnv, @argWords
        c.elemType = "EVAL"
        c
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
        v = new Word e.val, @wordEnv
      else if e.val instanceof ast.Block
        v = new Closure e.val, @wordEnv
      else
        v = e.val
      e = new ast.Elem v, name, e.srcInfo
      @words[name] = e

  elemEval: (e, ctx) ->
    @wordEnvInit()
    if      e.val instanceof ast.Word
      v = wordVal e.val, @wordEnv, ctx
      if v == undefined
        err "word:#{e.val.name} not defined", ctx, e.srcInfo
    else if e.val instanceof ast.Block
      args = []
      for name in @block.args
        if @argWords[name] == undefined
          args.push name
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
    for name in @block.args
      if @argWords[name] != undefined
        aw[name] = @argWords[name]
      if argWords[name] != undefined
        aw[name] = argWords[name]
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
    if found && e.val instanceof Closure && opt == "'"
      e.val = e.val.valDup ctx
    [found, e]

  setElem: (name, elem, ctx) ->
    [name, opt] = sepWordNameProc name
    if opt == "!"
      elem.val = elem.val.evalDup ctx
    if @block.argWords[name] != undefined
      aw = {}
      for aname in @block.args
        if @argWords[aname] != undefined
          aw[aname] = @argWords[aname]
      aw[aname] = elem
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

  concat: (other) ->
    b = @block.concat other.block
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













