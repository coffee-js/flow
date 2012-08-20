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
        err "redefined word:\"#{name}\"", e.val.srcInfo.pos, @srcInfo.src
      @words[name] = e.val
      @numWords += 1
    @elemType = "EVAL"

  specialize: (argWords) ->
    b = new ast.Block [], @wordSeq(), @seq, @srcInfo
    for a in @args
      if argWords[a.name] != undefined
        if b.words[a.name] != undefined
          err "redefined word:\"#{a.name}\"", @srcInfo.pos, @srcInfo.src
        b.words[a.name] = argWords[a.name]
        b.numWords += 1
      else
        b.args.push a
    b

  wordSeq: ->
    wordSeq = []
    for name of @words
      val = @words[name]
      wordSeq.push {name, val}
    wordSeq

  clone: ->
    new ast.Block @args.slice(0), @wordSeq(), @seq.slice(0), @srcInfo




