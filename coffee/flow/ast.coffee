ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


class ast.Node


class ast.NodeWord extends ast.Node
  constructor: (@name) ->


class ast.NodeElem extends ast.Node
  constructor: (@name, @val, @pos) ->


class ast.NodeBlock extends ast.Node
  constructor: (@args, @seq) ->
    @words = {}
    for e in @seq
      v = e.val
      if e.name != null
        if @words[e.name] != undefined
          throw "#{e.pos} redefined: #{e.name}"
        @words[e.name] = v
      if v instanceof ast.NodeBlock
        v.parent = @
    @parent = null
    if @args.length > 0
      @in = true
    else
      @in = undefined

  getWord: (name) ->
    word = @words[name]
    if word != undefined
      word
    else if @parent != null
      @parent.getWord name
    else
      null


class ast.Source
  constructor: (@txt, @path) ->

  lineCol: (pos)->
    line = 1
    lastLinePos = 0
    while lastLinePos = 1+@txt[0...pos].indexOf("\n",lastLinePos)
      ++line
    col = pos - lastLinePos + 1
    return [line, col]







