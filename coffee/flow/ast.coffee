ast = exports
pc = require "../pc"


class ast.Node


class ast.NodeWord extends ast.Node
  constructor: (@name) ->


class ast.NodeBlock extends ast.Node
  constructor: (@args, @seq) ->


class ast.NodeElem extends ast.Node
  constructor: (@name, @val, @pos) ->









