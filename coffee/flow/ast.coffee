ast = exports
pc = require "../pc"


log = (s) -> console.log s
p = (s) -> JSON.stringify s, null, '  '
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->


class ast.Elem extends ast.Node
  constructor: (@name, @val, @pos=null) ->


class ast.Block extends ast.Node
  constructor: (@args, @seq, @pos=null, @src=null) ->
    @words = {}
    argWords = {}
    for a in @args
      argWords[a.name] = null

    for e in @seq
      if e.name != null
        if (@words[e.name] != undefined) or (argWords[e.name] != undefined)
          err "redefined: #{e.name}", e.pos, @src
        @words[e.name] = e

  curry: (argWords) ->
    b = new ast.Block [], @seq, @pos, @src
    for a in @args
      if argWords[a.name] != undefined
        b.words[a.name] = argWords[a.name]
      else
        b.args.push a
    b










