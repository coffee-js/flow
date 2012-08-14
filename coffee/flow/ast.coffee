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

  init: (@src) ->
    inWords = {}
    for a in @args
      inWords[a.name] = null

    @words = {}
    for e in @seq
      v = e.val
      if e.name != null
        if (@words[e.name] != undefined) or (inWords[e.name] != undefined)
          [line, col] = @src.lineCol e.pos
          throw "#{line}:#{col} redefined: #{e.name}"
        @words[e.name] = v
      if v instanceof ast.NodeBlock
        v.init src
        v.parent = @
    @parent = null


class ast.Source
  constructor: (@txt, @path) ->

  lineCol: (pos)->
    line = 1
    lastLinePos = 0
    while lastLinePos = 1+@txt[0...pos].indexOf("\n",lastLinePos)
      ++line
    col = pos - lastLinePos + 1
    return [line, col]







