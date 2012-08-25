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
    @val = null


class ast.Elem extends ast.Node
  constructor: (@val, @name=null, srcInfo=null) ->
    if srcInfo == null
      @srcInfo = new ast.SrcInfo null, null
    else
      @srcInfo = srcInfo


class ast.Block extends ast.Node
  constructor: (@args, wordSeq, @seq, @elemType, srcInfo=null) ->
    if srcInfo == null
      @srcInfo = new ast.SrcInfo null, null
    else
      @srcInfo = srcInfo

    argWords = {}
    for a in args
      argWords[a.name] = null

    @words = {}
    @numWords = 0
    for e in wordSeq
      name = e.name
      if @words[name] != undefined or argWords[name] != undefined
        err "redefined word:\"#{name}\"", e.elem.srcInfo.pos, @srcInfo.src
      w = @words[name] = e.elem
      @numWords += 1


  linkWordsVal: (blocks=[]) ->
    getWord = (name, blocks) ->
      for i in [blocks.length...0]
        b = blocks[i-1]
        elem = b.words[name]
        if elem != undefined
          if elem.val instanceof ast.Word
            elem = getWord elem.val.name, blocks.slice(0,i)
          break
      elem

    blocks = blocks.concat [@]
    for e in @seq
      if e.val instanceof ast.Word
        name = e.val.name
        elem = getWord name, blocks
        if elem != undefined
          e.val.val = elem
      if e.val instanceof ast.Block
        e.val.linkWordsVal blocks










