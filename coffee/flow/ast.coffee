ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->


class ast.Elem extends ast.Node
  constructor: (@name, @val, @pos=null) ->


class ast.Block extends ast.Node
  constructor: (@args, @seq) ->
    @words = {}

  init: (@src=null) ->
    argWords = {}
    for a in @args
      argWords[a.name] = null

    for e in @seq
      v = e.val
      if e.name != null
        if (@words[e.name] != undefined) or (argWords[e.name] != undefined)
          if (e.pos != null) && (@src != null)
            [line, col] = @src.lineCol e.pos
            throw "#{line}:#{col} redefined: #{e.name}"
          else
            throw "#{@} redefined: #{e.name}"
        @words[e.name] = v
      if v instanceof ast.Block
        v.init @src

  curry: (argWords) ->
    b = new ast.Block [], @seq
    for a in @args
      if argWords[a.name] != undefined
        b.words[a.name] = argWords[a.name]
      else
        b.args.push a
    b.init @src
    b


class ast.Source
  constructor: (@txt, @path) ->

  lineCol: (pos)->
    line = 1
    lastLinePos = 0
    while lastLinePos = 1+@txt[0...pos].indexOf("\n",lastLinePos)
      ++line
    col = pos - lastLinePos + 1
    return [line, col]







