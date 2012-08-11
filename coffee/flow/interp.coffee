interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


getArgs = (n, ctx) ->
  l = ctx.values.length
  if l < n
    throw "no enough args #{ctx}"
  args = ctx.values.slice l-n
  ctx.values.length = l-n
  args

class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (ctx) ->
    args = (getArgs @numArgs, ctx).map (e)-> e.val
    a = [ctx].concat args
    @fn a...


bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (ctx, a, b) -> a+b
  "-":    bw 2, (ctx, a, b) -> a-b
  "*":    bw 2, (ctx, a, b) -> a*b
  "/":    bw 2, (ctx, a, b) -> a/b

  '=':    bw 2, (ctx, a, b) -> a==b
  '<':    bw 2, (ctx, a, b) -> a<b
  '>':    bw 2, (ctx, a, b) -> a>b
  '<=':   bw 2, (ctx, a, b) -> a<=b
  '>=':   bw 2, (ctx, a, b) -> a>=b

  'not':  bw 1, (ctx, a)    -> !a
  'and':  bw 2, (ctx, a, b) -> a&&b
  'or':   bw 2, (ctx, a, b) -> a||b

  'if':   bw 3, (ctx, cond, whenTrue, whenFals) ->
    if typeof(cond) != 'boolean'
      throw "cond is not a boolean: #{pp cond}"
    if !(whenTrue instanceof ast.NodeBlock)
      throw "whenTrue is not a block: #{pp whenTrue}"
    if !(whenFals instanceof ast.NodeBlock)
      throw "whenFals is not a block: #{pp whenFals}"

    if cond
      blockEval whenTrue, ctx
    else
      blockEval whenFals, ctx
}


class Context
  constructor: (@parent) ->
    @values = []
    @words = {}

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
  word = ctx.getWord node.name

  if      word instanceof BuildinWord
    word.eval ctx
  else if word instanceof ast.NodeElem
    v = word.val
    if      v instanceof ast.NodeBlock
      blockEval v, ctx
    else if v instanceof ast.NodeWord
      wordEval  v, ctx
    else if v != null
      v
  else
    args = []
    for e in ctx.values
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = node.name + "(" + a + ")"
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
        ctx.setWord a.name, v
      parentCtx.values.length = l - node.args.length

  for e in node.seq
    if e.name != null
      if (ctx.getWord e.name) != null
        throw "redefined: #{e.name}"
      ctx.setWord e.name, e

  for e in node.seq
    if (e.val instanceof ast.NodeWord) && (e.val.name == ";")
      ctx.values.length = 0
    else
      v = e.val
      if v instanceof ast.NodeWord
        v = wordEval v, ctx

      if v instanceof Array
        for ve in v
          ctx.values.push ve
      else
        ctx.values.push new ast.NodeElem null, v

  ctx.values



interp.eval = (seq) ->
  elems = blockEval (new ast.NodeBlock [], seq), null
  elems.map (e)-> e.val


