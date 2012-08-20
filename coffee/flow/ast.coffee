ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s



class ast.SrcInfo
  constructor: (@pos=null, @src=null) ->


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->


class ast.Elem extends ast.Node
  constructor: (@val, @name=null, @srcInfo=null) ->

  clone: ->
    if @val instanceof ast.Block
      v = @val.clone()
    else
      v = @val
    new ast.Elem v, @name, @srcInfo


class ast.Block extends ast.Node
  constructor: (@args, wordSeq, @seq, @srcInfo=null) ->
    argWords = {}
    for a in args
      argWords[a.name] = null

    @words = {}
    @numWords = 0
    for e in wordSeq
      name = e.name
      if (@words[name] != undefined) or (argWords[name] != undefined)
        err "redefined word:\"#{name}\"", e.word.srcInfo.pos, @srcInfo.src
      w = @words[name] = e.word
      log w
      @numWords += 1
      if w.val instanceof ast.Block
        w.val.parent = @

    for e in @seq
      if e.val instanceof ast.Block
        e.val.parent = @

    @parent = null
    @elemType = "EVAL"


  curry: (argWords) ->
    args = []

    wordSeq = @wordSeq().map (w) -> w.clone()
    seq = @seq.map (e) -> e.clone()

    for a in @args
      if argWords[a.name] != undefined
        name = a.name
        word = argWords[a.name].clone()
        wordSeq.push {name, word}
      else
        args.push a

    new ast.Block args, wordSeq, seq, @srcInfo


  getWord: (name) ->
    word = @words[name]
    if word != undefined
      word
    else if @parent
      @parent.getWord name
    else
      null


  wordSeq: ->
    wordSeq = []
    for name of @words
      word = @words[name]
      wordSeq.push {name, word}
    wordSeq


  clone: ->
    wordSeq = @wordSeq().map (w) -> w.clone()
    seq = @seq.map (e) -> e.clone()
    new ast.Block @args.slice(0), wordSeq, seq, @srcInfo




