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


buildinWords = {
  "+":    bw 2, (retSeq, a, b) -> a.val+b.val
  "-":    bw 2, (retSeq, a, b) -> a.val-b.val
  "*":    bw 2, (retSeq, a, b) -> a.val*b.val
  "/":    bw 2, (retSeq, a, b) -> a.val/b.val

  "=":    bw 2, (retSeq, a, b) -> a.val==b.val
  "<":    bw 2, (retSeq, a, b) -> a.val<b.val
  ">":    bw 2, (retSeq, a, b) -> a.val>b.val
  "<=":   bw 2, (retSeq, a, b) -> a.val<=b.val
  ">=":   bw 2, (retSeq, a, b) -> a.val>=b.val

  "not":  bw 1, (retSeq, a)    -> !a.val
  "and":  bw 2, (retSeq, a, b) -> a.val&&b.val
  "or":   bw 2, (retSeq, a, b) -> a.val||b.val

  "if":   bw 3, (retSeq, cond, whenTrue, whenFals) ->
    if typeof cond.val != 'boolean'
      err "expect a boolean: #{cond.val}", cond.srcInfo
    if !(whenTrue.val instanceof Closure)
      err "expect a block: #{whenTrue.val}", whenTrue.srcInfo
    if !(whenFals.val instanceof Closure)
      err "expect a block: #{whenFals.val}", whenFals.srcInfo

    if cond.val
      seqCurryEval whenTrue.val, retSeq
    else
      seqCurryEval whenFals.val, retSeq
    undefined

  "eval": bw 1, (retSeq, elem) ->
    c = elem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", elem.srcInfo
    seqCurryEval c, retSeq
    undefined

  "get":  bw 2, (retSeq, cElem, nameElem) ->
    c = cElem.val
    name = nameElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    
    [found, elem] = c.getElem name
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{c}", nameElem.srcInfo

  "set":  bw 3, (retSeq, cElem, elem, nameElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    name = nameElem.val
    c.setElem name, elem

  "len":  bw 1, (retSeq, cElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{cElem.val}", cElem.srcInfo
    c.len()

  "num-words": bw 1, (retSeq, cElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    c.numWords()

  "num-elems": bw 1, (retSeq, cElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    c.numElems()

  "slice":  bw 3, (retSeq, cElem, start, end) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    c.slice start.val, end.val

  "join":   bw 2, (retSeq, a, b) ->
    if !(a.val instanceof Closure)
      err "expect a block: #{a.val}", a.srcInfo
    if !(b.val instanceof Closure)
      err "expect a block: #{b.val}", b.srcInfo
    a.val.join b.val

  "splice":  bw 4, (retSeq, cElem, i, numDel, addElemsCElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo
    c.splice i.val, numDel.val, addElemsCElem.val.seq()

  "seq-curry": bw 2, (retSeq, cElem, nElem) ->
    c = cElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", elem.srcInfo
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
  e = wordInEnv(name, wordEnv)
  if e == undefined
    e = buildinWords[name]
  e


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

  wordEnvInit: ->
    if @wordEnv != undefined
      return
    @wordEnv = [@words].concat @preWordEnv
    for name of @block.words
      e = @block.words[name]
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
      v = new Closure e.val, @wordEnv
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
      e = new ast.Elem @elemEval(e), e.srcInfo
    [found, e]

  setElem: (name, elem) ->
    b = @block.setElem name, elem
    new Closure b, @preWordEnv, @argWords

  len: -> @block.len()
  numWords: -> @block.numWords + @numArgWords
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













