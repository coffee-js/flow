ast = exports
pc = require "../pc"


class ast.Node


class ast.NodeWord extends ast.Node
  constructor: (@name) ->


class ast.NodeBlock extends ast.Node
  constructor: (@args, @seq) ->


class ast.NodeElem extends ast.Node
  constructor: (@name, @val, @pos) ->



class ast.Source
  constructor: (@txt, @path) ->

  lineCol: (pos)->
    line = 1
    lastLinePos = 0
    while lastLinePos = 1+@txt[0...pos].indexOf("\n",lastLinePos)
      ++line
    col = pos - lastLinePos + 1
    return [line, col]







