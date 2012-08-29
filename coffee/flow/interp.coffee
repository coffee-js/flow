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

  eval: (elem, retSeq) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", elem.srcInfo
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
      #log whenTrue.val.args
      seqCurryEval whenTrue.val, retSeq
    else
      #log whenFals
      seqCurryEval whenFals.val, retSeq
    undefined

  "eval":   bw 1, (retSeq, elem) ->
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
    c.splice i.val, numDel.val, addElemsCElem.val.seq
}


wordInEnv = (word, wordEnv) ->
  name = word.name
  for i in [0...wordEnv.length]
    words = wordEnv[i]
    w = words[name]
    if w != undefined
      if w.val instanceof ast.Word
        return wordInEnv w.val, wordEnv.slice(i)
      else
        return w.val
  undefined


wordEval = (wordElem, wordEnv) ->
  name = wordElem.val.name
  w = wordInEnv wordElem.val, wordEnv
  if w == undefined
    w = buildinWords[name]
  w


seqCurryArgWords = (c, retSeq, n, srcInfo=null) ->
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c} max args num is #{c.args.length}", srcInfo
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


valEval = (val, e, retSeq, wordEnv) ->
  if val instanceof Closure && val.elemType == "EVAL"
    seqCurryEval val, retSeq, e.srcInfo
  else if val instanceof BuildinWord
    v = val.eval e, retSeq
    if v != undefined
      valEval v, e, retSeq, wordEnv
  else
    retSeq.push new Elem val, wordEnv, e.srcInfo


closureFromBlock = (b, preWordEnv, preArgs=[]) ->
  args = preArgs.concat b.args
  words = {}

  for name of b.words
    hasWords = true
    break
  if hasWords
    wordEnv = [words].concat preWordEnv
  else
    wordEnv = preWordEnv

  for name of b.words
    e = b.words[name]
    if e.val instanceof ast.Block
      v = closureFromBlock e.val, wordEnv, args
      words[name] = new Elem v, wordEnv, e.srcInfo
    else
      words[name] = e

  seq = b.seq.map (e) ->
    if e.val instanceof ast.Block
      v = closureFromBlock e.val, wordEnv, args
    else
      v = e.val
    new Elem v, wordEnv, e.srcInfo

  new Closure args, words, seq, b.elemType


elemVal = (e) ->
  if e.val instanceof ast.Word
    v = wordEval e, e.wordEnv
    if v == undefined
      err "word:#{e.val.name} not defined", e.srcInfo
  else
    v = e.val
  v


class Elem
  constructor: (@val, @wordEnv, @srcInfo=null) ->


class Closure
  constructor: (@args, @words, @seq, @elemType) ->

  curry: (argWords) ->
    if argWords == {}
      @
    else
      args = []
      words = {}
      for a in @args
        if argWords[a.name] != undefined
          words[a.name] = argWords[a.name]
          hasWords = true
        else
          args.push a

      for name of @words
        e = @words[name]
        if e.val instanceof Closure
          v = e.val.curry argWords
        else
          v = e.val
        if hasWords
          wordEnv = [words].concat e.wordEnv
        else
          wordEnv = e.wordEnv
        @words[name] = new Elem v, wordEnv, e.srcInfo

      seq = @seq.map (e) ->
        if e.val instanceof Closure
          v = e.val.curry argWords
        else
          v = e.val
        if hasWords
          wordEnv = [words].concat e.wordEnv
        else
          wordEnv = e.wordEnv
        new Elem v, wordEnv, e.srcInfo
      new Closure args, words, seq, @elemType

  eval: (retSeq) ->
    for e in @seq
      valEval elemVal(e), e, retSeq, e.wordEnv

  getElem: (name) ->
    found = false
    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name
    if n != undefined
      if n<0 then n = @seq.length+n+1
      elem = @seq[n-1]
      if elem != undefined
        found = true
      else
        elem = null
    else
      elem = @words[name]
      if elem != undefined
        found = true
      else
        elem = null
    [found, elem]

  setElem: (name, elem) ->
    seq = @seq.slice 0
    words = {}
    for name of @words
      words[name] = @words[name]
    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name
    if n != undefined
      if n<0 then n = seq.length+n+1
      seq[n-1] = elem
    else
      words[name] = elem
    new Closure @args, words, seq, @elemType

  len: ->
    @seq.length

  numWords: ->
    if @_numWords == undefined
      @_numWords = 0
      for name of @words
        @_numWords += 1
      @_numWords
    else
      @_numWords

  numElems: ->
    @numWords() + @len()

  slice: (p1, p2) ->
    if p1 < 0 then p1 = @seq.length + p1 + 1
    if p2 < 0 then p2 = @seq.length + p2 + 1
    seq = @seq.slice p1-1, p2
    new Closure @args, @words, seq, @elemType

  join: (other) ->
    args = []
    argWords = {}
    i = 0
    for a in @args
      argWords[a.name] = i
      args.push a
      i += 1
    for a in other.args
      if argWords[a.name] != undefined
        args[ argWords[a.name] ] = a
      else
        args.push a
    seq = @seq.concat other.seq
    words = {}
    for name of @words
      words[name] = @words[name]
    for name of other.words
      words[name] = other.words[name]
    new Closure args, words, seq, @elemType

  splice: (i, numDel, addElems) ->
    seq = @seq.slice 0
    seq.splice i-1, numDel, addElems...
    new Closure @args, @words, seq, @elemType



interp.eval = (blockElem) ->
  retSeq = []
  c = closureFromBlock blockElem.val, []
  c.eval retSeq
  retSeq













