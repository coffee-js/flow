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

getArgs1 = (ctx) -> getArgs 1, ctx
getArgs2 = (ctx) -> getArgs 2, ctx
getArgs3 = (ctx) -> getArgs 3, ctx


buildinWords = {
  "+":    (ctx) -> [a,b] = getArgs2 ctx; [a+b]
  "-":    (ctx) -> [a,b] = getArgs2 ctx; [a-b]
  "*":    (ctx) -> [a,b] = getArgs2 ctx; [a*b]
  "/":    (ctx) -> [a,b] = getArgs2 ctx; [a/b]

  '=':    (ctx) -> [a,b] = getArgs2 ctx; [a==b]
  '<':    (ctx) -> [a,b] = getArgs2 ctx; [a<b]
  '>':    (ctx) -> [a,b] = getArgs2 ctx; [a>b]
  '<=':   (ctx) -> [a,b] = getArgs2 ctx; [a<=b]
  '>=':   (ctx) -> [a,b] = getArgs2 ctx; [a>=b]

  'not':  (ctx) -> [a]   = getArgs1 ctx; [!a]
  'and':  (ctx) -> [a,b] = getArgs2 ctx; [a&&b]
  'or':   (ctx) -> [a,b] = getArgs2 ctx; [a||b]

  'if':   (ctx) ->
    [cond, whenTrue, whenFals] = getArgs3(ctx)

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
    else if @parent
      @parent.getWord name
    else if buildinWords[name]
      buildinWords[name]
    else
      null


elemEval = (node, ctx) ->
  nodeEval node.val, ctx


nodeEval = (node, ctx) ->
  if      node instanceof ast.NodeValue
    valueEval node, ctx
  else if node instanceof ast.NodeWord
    wordEval  node, ctx
  else if node instanceof ast.NodeBlock
    node
  else
    throw "unsupport node:\n#{pp node}"


valueEval = (node) -> node.val


wordEval = (node, ctx) ->
  word = ctx.getWord node.name

  if      word instanceof ast.NodeBlock
    v = blockEval word, ctx
  else if word instanceof ast.Node
    v = nodeEval word, ctx
  else if !(word instanceof Function) && (word != null)
    v = word
  else if word instanceof Function
    v = word ctx
  else
    args = []
    for v in ctx.values
      if typeof(v)=='string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = node.name + "(" + a + ")"
    v = eval jsCode
  v


blockEval = (node, parentCtx) ->
  ctx = new Context parentCtx

  if node.args.length > 0
    if !parentCtx
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
    if e.name
      if ctx.getWord e.name
        throw "redefined: #{e.name}"
      ctx.setWord e.name, e.val

  for e in node.seq
    if (e.val instanceof ast.NodeWord) && (e.val.name == ";")
      ctx.values.length = 0
    else
      v = elemEval e, ctx
      if v instanceof Array
        for ve in v
          ctx.values.push ve
      else
        ctx.values.push v

  ctx.values



interp.eval = (seq) ->
  blockEval (new ast.NodeBlock [], seq), null



