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
  a.map (v) -> new ast.NodeElem null, v


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
    if !(whenTrue instanceof ast.NodeBlock)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} whenTrue is not a block: #{whenTrue}"
    if !(whenFals instanceof ast.NodeBlock)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} whenFals is not a block: #{whenFals}"

    if cond
      blockEval whenTrue, ctx
    else
      blockEval whenFals, ctx

  'do':   bw 1, (e, ctx, blk) ->
    if !(blk instanceof ast.NodeBlock)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} #{blk} is not a block"
    blockEval blk, ctx
}


class Context
  constructor: (@parent, @src=null) ->
    @values = []
    @words = {}

  source: ->
    if @src == null
      @parent.source()
    else
      @src

  setWord: (name, word) ->
    @words[name] = word

  getWord: (name) ->
    word = @words[name]
    if word != undefined
      word
    else if @parent != null
      @parent.getWord name
    else if buildinWords[name] != undefined
      buildinWords[name]
    else
      null


wordEval = (node, ctx) ->
  word = ctx.getWord node.val.name

  if      word instanceof ast.NodeBlock
    blockEval word, ctx
  else if word instanceof ast.NodeWord
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


blockEval = (node, parentCtx) ->
  ctx = new Context parentCtx

  if node.args.length > 0
    if parentCtx == null
      throw "no enough args #{pp name}"
    else
      l = parentCtx.values.length
      if l < node.args.length
        throw "no enough args #{pp name}"

      for i in [0..node.args.length-1]
        a = node.args[i]
        v = parentCtx.values[l-i-1]
        ctx.setWord a.name, v.val
      parentCtx.values.length = l - node.args.length

  for e in node.seq
    if e.name != null
      if (ctx.getWord e.name) != null
        [line, col] = ctx.source().lineCol e.pos
        throw "#{line}:#{col} redefined: #{e.name}"
      ctx.setWord e.name, e.val

  for e in node.seq
    v = e.val
    if v instanceof ast.NodeWord
      v = wordEval e, ctx

    if v instanceof Array
      for ve in v
        ctx.values.push ve
    else
      ctx.values.push new ast.NodeElem null, v

  ctx.values



interp.eval = (seq, src) ->
  ctx = new Context null, src
  a = blockEval (new ast.NodeBlock [], seq), ctx
  a.map (e)-> e.val


