interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, srcInfo=null) ->
  if srcInfo != null
    src = srcInfo.src
    [line, col] = src.lineCol srcInfo.pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s



class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (retSeq, srcInfo=null) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", srcInfo
    retSeq.length = retSeq.length-@numArgs
    args = [retSeq].concat args
    @fn args...


bw = ->
  new BuildinWord arguments...

ct = (e, ta...) ->
  for t in ta
    if typeof(e.val) == t
      pass = true
  if !pass
    ts = ta.join " or "
    err "expect a #{ts}, got:[#{e.val}:#{typeof(e.val)}]", e.srcInfo

ct2 = (a, b, t) ->
  ct a, t; ct b, t

ck = (e, ka...) ->
  ct e, "object"
  for k in ka
    if e.val instanceof k
      pass = true
  if !pass
    ks = ka.join " or "
    err "expect a #{ks}: #{e.val}", e.srcInfo


buildinWords = {
  "+":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val+b.val
  "-":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val-b.val
  "*":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val*b.val
  "/":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val/b.val

  "=":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val==b.val
  "<":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val<b.val
  ">":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val>b.val
  "<=":   bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val<=b.val
  ">=":   bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val>=b.val

  "not":  bw 1, (retSeq, a)    -> ct a, "boolean"; !a.val
  "and":  bw 2, (retSeq, a, b) -> ct2 a, b, "boolean"; a.val&&b.val
  "or":   bw 2, (retSeq, a, b) -> ct2 a, b, "boolean"; a.val||b.val

  "if":   bw 3, (retSeq, cond, whenTrue, whenFals) ->
    ct cond, 'boolean'
    ck whenTrue, Closure
    ck whenFals, Closure

    if cond.val
      seqCurryEval whenTrue.val, retSeq
    else
      seqCurryEval whenFals.val, retSeq
    undefined

  "eval": bw 1, (retSeq, elem) ->
    ck elem, Closure
    c = elem.val
    seqCurryEval c, retSeq
    undefined

  "get":  bw 2, (retSeq, cElem, nameElem) ->
    ck cElem, Closure
    ct nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    [found, elem] = c.getElem name
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{c}", nameElem.srcInfo

  "set":  bw 3, (retSeq, cElem, elem, nameElem) ->
    ck cElem, Closure
    ct nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    c.setElem name, elem

  "len":  bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.len()

  "num-words": bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.numWords()

  "num-elems": bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.numElems()

  "slice":  bw 3, (retSeq, cElem, start, end) ->
    ck cElem, Closure
    ct start, "number"; ct end, "number"

    c = cElem.val
    c.slice start.val, end.val

  "join":   bw 2, (retSeq, a, b) ->
    ck a, Closure; ck b, Closure
    a.val.join b.val

  "splice":  bw 4, (retSeq, cElem, iElem, numDelElem, addElemsCElem) ->
    ck cElem, Closure
    ct iElem, "number"; ct numDelElem, "number"

    ck addElemsCElem, Closure
    c = cElem.val
    c.splice iElem.val, numDelElem.val, addElemsCElem.val.seq()

  "seq-curry": bw 2, (retSeq, cElem, nElem) ->
    ck cElem, Closure
    ct nElem, "number"

    c = cElem.val
    n = nElem.val
    if n > c.args.length
      argN = c.args.length
      seqN = n - c.args.length
    else
      argN = n
    argWords = seqCurryArgWords c, retSeq, argN, cElem.srcInfo
    r = c.curry argWords
    if seqN != undefined
      unshifts = retSeq.slice -seqN
      retSeq.length = retSeq.length-seqN
      r = r.splice 1, 0, unshifts
    r
}



wordInEnv = (name, wordEnv) ->
  for words in wordEnv
    e = words[name]
    if e != undefined
      if e.val instanceof Word
        return wordInEnv e.val.name, e.val.wordEnv
      else
        return e.val
  undefined

wordVal = (name, wordEnv) ->
  if name[0] == "'"
    notEval = true
    name = name.slice 1
  v = wordInEnv(name, wordEnv)
  if v == undefined
    v = buildinWords[name]
  else if notEval
    v = v.val()
  v


seqCurryArgWords = (c, retSeq, n, srcInfo=null) ->
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c} args count:#{c.args.length} < #{n}", srcInfo
  argWords = {}
  args = retSeq.slice -n
  for i in [0..n-1]
    a = c.args[i]
    w = args[i]
    argWords[a.name] = w
  retSeq.length = retSeq.length-n
  argWords

seqCurryEval = (c, retSeq, srcInfo=null) ->
  if c.args.length > 0
    argWords = seqCurryArgWords c, retSeq, c.args.length, srcInfo
    (c.curry argWords).eval retSeq
  else
    c.eval retSeq


seqEval = (val, retSeq, wordEnv, srcInfo=null) ->
  if val instanceof Closure && val.elemType == "EVAL"
    seqCurryEval val, retSeq, srcInfo
  else if val instanceof BuildinWord
    v = val.eval retSeq, srcInfo
    if v != undefined
      seqEval v, retSeq, wordEnv
  else
    retSeq.push new ast.Elem val, srcInfo


class Word
  constructor: (@name, @wordEnv) ->


class Closure
  constructor: (@block, @preWordEnv, argWords=null) ->
    @elemType = @block.elemType
    @words = {}
    @argWords = {}
    @numArgWords = 0
    if argWords
      @args = []
      for a in @block.args
        if argWords[a.name] == undefined
          @args.push a
        else
          @words[a.name] = @argWords[a.name] = argWords[a.name]
          @numArgWords += 1
    else
      @args = @block.args

  val: ->
    switch @elemType
      when "EVAL"
        c = new Closure @block, @preWordEnv, @argWords
        c.elemType = "VAL"
        c
      when "VAL"
        @
      else
        err "fatal error: #{@} @elemType:#{@elemType}"

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

  elemEval: (e) ->
    @wordEnvInit()
    if      e.val instanceof ast.Word
      v = wordVal e.val.name, @wordEnv
      if v == undefined
        err "word:#{e.val.name} not defined", e.srcInfo
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

  eval: (retSeq) ->
    for e in @block.seq
      seqEval @elemEval(e), retSeq, @wordEnv, e.srcInfo

  curry: (argWords) ->
    aw = {}
    for a in @block.args
      if @argWords[a.name] != undefined
        aw[a.name] = @argWords[a.name]
      if argWords[a.name] != undefined
        aw[a.name] = argWords[a.name]
    new Closure @block, @preWordEnv, aw

  seq: ->
    if @_seq != undefined
      return @_seq
    @_seq = []
    for e in @block.seq
      @_seq.push new ast.Elem @elemEval(e), e.srcInfo
    @_seq

  getElem: (name) ->
    [found, e] = @block.getElem name
    if found
      if e != null
        e = new ast.Elem @elemEval(e), e.srcInfo
      else if @argWords[name] != undefined
        e = @argWords[name]
      else
        found = false
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
  numWords: -> @block.numWords - @block.args.length + @numArgWords
  numElems: -> @len() + @numWords()

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

  splice: (i, numDel, addElems) ->
    b = @block.splice i, numDel, addElems
    new Closure b, @preWordEnv, @argWords



interp.eval = (blockElem) ->
  retSeq = []
  c = new Closure blockElem.val, []
  c.eval retSeq
  retSeq













