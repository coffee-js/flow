ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, srcInfo=null) ->
  if srcInfo != null
    src = srcInfo.src
    [line, col] = src.lineCol srcInfo.pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


class ast.SrcInfo
  constructor: (@pos=null, @src=null) ->


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->


class ast.Elem extends ast.Node
  constructor: (@val, @srcInfo=null) ->


class ast.Block extends ast.Node
  constructor: (@args, wordSeq, @seq, @elemType, @srcInfo=null) ->
    @numWords = 0
    argWords = {}
    for a in args
      argWords[a.name] = null
      @numWords += 1

    @words = {}
    for e in wordSeq
      name = e.name
      if @words[name] != undefined or argWords[name] != undefined
        err "redefined word:\"#{name}\"", e.elem.srcInfo
      @words[name] = e.elem
      @numWords += 1


  wordSeq: ->
    wordSeq = []
    for name of @words
      elem = @words[name]
      wordSeq.push {name, elem}
    wordSeq


  clone: ->
    new ast.Block @args.slice(0), @wordSeq(), @seq.slice(0), @elemType, @srcInfo


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
    blk = @clone()
    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name
    if n != undefined
      if n<0 then n = blk.seq.length+n+1
      blk.seq[n-1] = elem
    else
      blk.words[name] = elem
    blk


  len: ->
    @seq.length


  numElems: ->
    @numWords + @len()


  slice: (p1, p2) ->
    if p1 < 0 then p1 = @seq.length + p1 + 1
    if p2 < 0 then p2 = @seq.length + p2 + 1
    seq = @seq.slice p1-1, p2
    new ast.Block @args, @wordSeq(), seq, @elemType, @srcInfo


  join: (other) ->
    args = []
    argWordIdx = {}
    i = 0
    for a in @args
      argWordIdx[a.name] = i
      args.push a
      i += 1
    for a in other.args
      if argWordIdx[a.name] != undefined
        args[ argWordIdx[a.name] ] = a
      else
        args.push a
    
    wordSeq = []
    myWordSeq = @wordSeq()
    wordIdx = {}
    i = 0
    for w in myWordSeq
      wordIdx[w.name] = i
      wordSeq.push w
      i += 1
    otherWordSeq = other.wordSeq()
    for w in otherWordSeq
      if wordIdx[w.name] != undefined
        wordSeq[ wordIdx[w.name] ] = w
      else
        wordSeq.push w

    seq = @seq.concat other.seq
    new ast.Block args, wordSeq, seq, "VAL", null


  splice: (i, numDel, addElems) ->
    seq = @seq.slice 0
    seq.splice i-1, numDel, addElems...
    new ast.Block @args, @wordSeq(), seq, @elemType, @srcInfo













