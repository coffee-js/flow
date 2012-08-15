interp = exports
ast = require "./ast"


log = (s) -> console.log s
p = (s) -> JSON.stringify s, null, '  '
pp = (s) -> console.log p s



getArgs = (e, n, ctx) ->
  l = ctx.values.length
  if l < n
    if ctx.parent == null
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} no enough args in context:#{p ctx}"
    else
      args0 = getArgs e, n-l, ctx.parent
  p = if l-n < 0 then 0 else l-n
  args = ctx.values.slice p
  if args0 != undefined
    args = args0.concat args
  ctx.values.length = p
  args


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (e, ctx) ->
    args = (getArgs e, @numArgs, ctx).map (a)-> a.val
    a = [e, ctx].concat args
    @fn a...


bw = ->
  new BuildinWord arguments...

ne = (a) ->
  a.map (v) -> new ast.Elem null, v


buildinWords = {
  ";":    bw 0, (e, ctx) -> ctx.values.length = 0; []

  "+":    bw 2, (e, ctx, a, b) -> ne [a+b]
  "-":    bw 2, (e, ctx, a, b) -> ne [a-b]
  "*":    bw 2, (e, ctx, a, b) -> ne [a*b]
  "/":    bw 2, (e, ctx, a, b) -> ne [a/b]

  '=':    bw 2, (e, ctx, a, b) -> ne [a==b]
  '<':    bw 2, (e, ctx, a, b) -> ne [a<b]
  '>':    bw 2, (e, ctx, a, b) -> ne [a>b]
  '<=':   bw 2, (e, ctx, a, b) -> ne [a<=b]
  '>=':   bw 2, (e, ctx, a, b) -> ne [a>=b]

  'not':  bw 1, (e, ctx, a)    -> ne [!a]
  'and':  bw 2, (e, ctx, a, b) -> ne [a&&b]
  'or':   bw 2, (e, ctx, a, b) -> ne [a||b]

  'if':   bw 3, (e, ctx, cond, whenTrue, whenFals) ->
    if typeof(cond) != 'boolean'
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} cond is not a boolean: #{cond}"
    if !(whenTrue instanceof ast.Block)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} whenTrue is not a block: #{whenTrue}"
    if !(whenFals instanceof ast.Block)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} whenFals is not a block: #{whenFals}"

    if cond
      blockEval whenTrue, ctx
    else
      blockEval whenFals, ctx

  'do':   bw 1, (e, ctx, blk) ->
    if !(blk instanceof ast.Block)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} #{blk} is not a block"
    blockEval blk, ctx
}


class Context
  constructor: (@parent, @block) ->
    @values = []
    @inWords = {}

  source: ->
    @block.src

  setInWord: (name, word) ->
    @inWords[name] = word

  getWord: (name, blk) ->
    if blk == @block
      if @inWords[name] != undefined
        word = @inWords[name]
      else if @block.words[name] != undefined
        word = @block.words[name]
      else
        upBlk = @block.parent

    if word != undefined
      word
    else if @parent
      if upBlk != undefined
        @parent.getWord name, upBlk
      else
        @parent.getWord name, blk
    else if buildinWords[name] != undefined
      buildinWords[name]
    else
      null


wordEval = (node, ctx) ->
  word = ctx.getWord node.val.name, ctx.block

  if      word instanceof ast.Block
    blockEval word, ctx
  else if word instanceof ast.Word
    wordEval  word, ctx
  else if word instanceof BuildinWord
    word.eval node, ctx
  else if word != null
    word
  else
    args = []
    for e in ctx.values
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = node.val.name + "(" + a + ")"
    eval jsCode


curryBlock = (e, ctx, l) ->
  blk = e.val
  if l > blk.args.length
    [line, col] = ctx.source().lineCol e.pos
    throw "#{line}:#{col} l > blk.args.length"
  args = getArgs e, l, ctx
  argWords = {}

  for i in [0..l-1]
    a = blk.args[i]
    v = ctx.values[l-i-1]
    argWords[a.name] = v.val
  b = blk.curry argWords
  b


blockEval = (e, parentContext) ->
  ctx = new Context parentContext, e

  for e in ctx.block.seq
    v = e.val
    if v instanceof ast.Word
      v = wordEval e, ctx

    if v instanceof Array
      for ve in v
        ctx.values.push ve
    else
      ctx.values.push new ast.Elem null, v

  ctx.values



interp.eval = (blk) ->
  ctx = new Context null, blk
  a = blockEval blk, ctx
  a.map (e)-> e.val


