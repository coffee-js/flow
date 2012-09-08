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
      a.unshift "from #{ast.toStr b.srcInfo}"
    ctxInfo = a.join "\n"
  if (srcInfo != null) or (srcInfo != undefined)
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
    if typeof(e) == t
      pass = true
  if !pass
    ts = ta.join " or "
    err "expect a #{ts}, got:[#{ast.toStr(e)}:#{typeof(e)}]", ctx, e.srcInfo

ct2 = (ctx, a, b, t) ->
  ct ctx, a, t; ct ctx, b, t

ck = (ctx, e, ka...) ->
  ct ctx, e, "object"
  for k in ka
    if e instanceof k
      pass = true
  if !pass
    ks = ka.join " or "
    err "expect a #{ks}: #{ast.toStr(e)}", ctx, e.srcInfo


buildinWords = {
  "+":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a+b
  "-":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a-b
  "*":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a*b
  "/":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a/b
  "%":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a%b
  "neg":  bw 1, (ctx, a)    -> ct  ctx, a,    "number"; -a
  "abs":  bw 1, (ctx, a)    -> ct  ctx, a,    "number"; Math.abs a

  "=":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a==b
  "<":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a<b
  ">":    bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a>b
  "<=":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a<=b
  ">=":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "number"; a>=b

  "not":  bw 1, (ctx, a)    -> ct  ctx, a,    "boolean"; !a
  "and":  bw 2, (ctx, a, b) -> ct2 ctx, a, b, "boolean"; a&&b
  "or":   bw 2, (ctx, a, b) -> ct2 ctx, a, b, "boolean"; a||b

  "if":   bw 3, (ctx, cond, whenTrue, whenFals) ->
    ct ctx, cond, "boolean"
    ck ctx, whenTrue, Closure
    ck ctx, whenFals, Closure

    if cond
      seqApplyEval whenTrue, ctx
    else
      seqApplyEval whenFals, ctx
    undefined

  "apply": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    seqApply c, ctx

  "do": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    seqApplyEval c, ctx
    undefined

  "len":  bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.len()

  "count-arg-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.argWordCount

  "count-non-arg-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.nonArgWordCount()

  "count-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.wordCount()

  "count-arg-slots": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.argSlotCount()

  "count": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.count()

  "slice": bw 3, (ctx, c, start, end) ->
    ck ctx, c, Closure
    ct ctx, start, "number"
    ct ctx, end, "number"
    c.slice start, end

  "concat": bw 2, (ctx, a, b) ->
    ck ctx, a, Closure
    ck ctx, b, Closure
    a.concat b

  "splice": bw 4, (ctx, c, i, delCount, addElemsC) ->
    ck ctx, c, Closure
    ct ctx, i, "number"
    ct ctx, delCount, "number"
    ck ctx, addElemsC, Closure
    c.splice i, delCount, addElemsC.seq(ctx)

  "curry": bw 2, (ctx, c, n) ->
    ck ctx, c, Closure
    ct ctx, n, "number"

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

  "wapply": bw 2, (ctx, w, c) ->
    ck ctx, w, Closure
    ck ctx, c, Closure
    w.wordEnvInit()
    argWords = w.words
    c.apply argWords

  "filter-arg-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.filterArgWords()

  "filter-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.filterWords()

  "filter-non-arg-words": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.filterNonArgWords()

  "filter-seq": bw 1, (ctx, c) ->
    ck ctx, c, Closure
    c.filterSeq()

  "map": bw 2, (ctx, c, b) ->
    ck ctx, c, Closure
    ck ctx, b, Closure
    oldRetSeqLen = ctx.retSeq.length

    wordSeq = []
    for name of c.words
      if c.block.argWords[name] != undefined
        continue
      ctx.retSeq.push c.words[name]
      seqApplyEval b, ctx
      elem = ctx.retSeq.pop()
      wordSeq.push {name, elem}

    seq = []
    for e in c.seq(ctx)
      ctx.retSeq.push e
      seqApplyEval b, ctx
      e = ctx.retSeq.pop()
      seq.push e

    argWords = {}
    for name of c.argWords
      ctx.retSeq.push c.argWords[name]
      seqApplyEval b, ctx
      e = ctx.retSeq.pop()
      argWords[name] = e

    if oldRetSeqLen != ctx.retSeq.length
      err "retSeq len:#{ctx.retSeq.length} not eq before:#{oldRetSeqLen}", ctx, b.srcInfo

    block = new ast.Block b.block.args, wordSeq, seq, b.block.elemType, null
    new Closure block, b.block.wordEnv, argWords


  "filter": bw 2, (ctx, c, b) ->
    ck ctx, c, Closure
    ck ctx, b, Closure
    oldRetSeqLen = ctx.retSeq.length

    wordSeq = []
    for name of c.words
      if c.block.argWords[name] != undefined
        continue
      elem = c.words[name]
      ctx.retSeq.push elem
      seqApplyEval b, ctx
      if ctx.retSeq.pop()
        wordSeq.push {name, elem}

    seq = []
    for e in c.seq(ctx)
      ctx.retSeq.push e
      seqApplyEval b, ctx
      if ctx.retSeq.pop()
        seq.push e

    argWords = {}
    for name of c.argWords
      e = c.argWords[name]
      ctx.retSeq.push e
      seqApplyEval b, ctx
      if ctx.retSeq.pop()
        argWords[name] = e

    if oldRetSeqLen != ctx.retSeq.length
      err "retSeq len:#{ctx.retSeq.length} not eq before:#{oldRetSeqLen}", ctx, b.srcInfo

    block = new ast.Block b.block.args, wordSeq, seq, b.block.elemType, null
    new Closure block, b.block.wordEnv, argWords

  "fold": bw 3, (ctx, c, a, b) ->
    ck ctx, c, Closure
    ck ctx, b, Closure
    oldRetSeqLen = ctx.retSeq.length

    seq = []
    for e in c.seq(ctx)
      ctx.retSeq.push a
      ctx.retSeq.push e
      seqApplyEval b, ctx
      a = ctx.retSeq.pop()

    if oldRetSeqLen != ctx.retSeq.length
      err "retSeq len:#{ctx.retSeq.length} not eq before:#{oldRetSeqLen}", ctx, b.srcInfo
    a
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
      if e instanceof Word
        return wordVal e, e.wordEnv, ctx
      else
        return e
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
    if word.opt != null && word.opt[0] == "#"
      n = 2
    else
      n = 1
    if ctx.retSeq.length < n
      err "no enough args in seq:#{ctx.retSeq}", ctx, srcInfo
    v = ctx.retSeq[ctx.retSeq.length-n]
    ck ctx, v, Closure
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
    v = e
  if word.opt == "'"
    if !(v instanceof Closure)
      err "word:#{word.name} is not a block", ctx, srcInfo
    v = v.valDup ctx
  else if word.opt != null && word.opt[0] == "#"
    if word.entry != null
      elem = ctx.retSeq.pop()
    else
      elem = ctx.retSeq[ctx.retSeq.length-n+1]
    name = word.refines[refines.length]
    if word.opt == "#!"
      name = "!#{name}"
    v = v.setElem name, elem, ctx
    v = v.valDup ctx
  if word.entry == null
    ctx.retSeq.length = ctx.retSeq.length-n
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


seqEval = (e, ctx, wordEnv) ->
  if      e instanceof Closure && e.elemType == "EVAL"
    seqApplyEval e, ctx
  else if e instanceof BuildinWord
    v = e.eval ctx
    if v != undefined
      seqEval v, ctx, wordEnv
  else
    if ctx.debug
      srcInfo = ctx.debug.pElem().srcInfo
    else
      srcInfo = null
    ctx.retSeq.push e


class Word
  constructor: (w, @wordEnv) ->
    @entry = w.entry
    @refines = w.refines
    @name = w.name
    @opt = w.opt
    @srcInfo = w.srcInfo


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
      if      e instanceof ast.Word
        v = new Word e, @wordEnv
      else if e instanceof ast.Block
        v = new Closure e, @wordEnv
      else
        v = e
      @words[name] = v

  elemEval: (e, ctx) ->
    @wordEnvInit()
    if      e instanceof ast.Word
      v = wordVal e, @wordEnv, ctx
      if v == undefined
        err "word:#{e.name} not defined", ctx, e.srcInfo
    else if e instanceof ast.Block
      args = []
      for name in @block.args
        if @argWords[name] == undefined
          args.push name
      b = e.addArgs args
      v = new Closure b, @wordEnv
    else
      v = e
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
    if @_seq == undefined
      @_seq = []
      for e in @block.seq
        @_seq.push @elemEval(e, ctx)
    @_seq

  elems: (ctx) ->
    if @_elems == undefined
      @_elems = seq ctx
      for name of @words
        @_elems.push @words[name]
    @_elems

  getElem: (name, ctx) ->
    [name, opt] = sepWordNameProc name
    [found, e] = @block.getElem name
    if found
      if e != null
        e = @elemEval e, ctx
      else if @argWords[name] != undefined
        e = @argWords[name]
      else
        found = false
    if found && e instanceof Closure && opt == "'"
      e = e.valDup ctx
    [found, e]

  setElem: (name, elem, ctx) ->
    [name, opt] = sepWordNameProc name
    if opt == "!"
      elem = elem.evalDup ctx
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



interp.eval = (b) ->
  ctx = new Context
  ctx.debug = new DebugContex null, b
  c = new Closure b, []
  c.eval ctx
  ctx.retSeq













