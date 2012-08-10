interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp  = (s) -> console.log JSON.stringify s, null, '  '


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
    [cond, whenTrue, whenFalse] = getArgs3(ctx)

    if !(whenTrue instanceof ast.NodeBlock)
      throw "whenTrue is not a block: #{pp whenTrue}"
    if !(whenFalse instanceof ast.NodeBlock)
      throw "whenFalse is not a block: #{pp whenFalse}"

    if cond
      blockEval whenTrue, ctx
    else
      blockEval whenFalse, ctx
}


class Context
  constructor: (@parent, @node, @name) ->
    @values = []
    @words = {}
    if @name
      @words[@name] = @node

  getWord: (name) ->
    word = @words[name]
    if word
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
    v = blockEval word, ctx, node.name
  else if word instanceof ast.Node
    v = nodeEval word, ctx
  else if !(word instanceof Function) && (word != undefined)
    v = word
  else if word instanceof Function
    v = word ctx
  else
    v = eval node.name ctx.values...
  v


blockEval = (node, parentCtx, name) ->
  ctx = new Context parentCtx, node, name

  needArgs = node.args.length > 0

  if !parentCtx && needArgs
    throw "no enough args #{pp name}"

  if parentCtx && needArgs
    l = parentCtx.values.length
    if l < node.args.length
      throw "no enough args #{pp name}"

    for i in [0..node.args.length-1]
      a = node.args[i]
      v = parentCtx.values[l-i-1]
      ctx.words[a.name] = v

    parentCtx.values.length = l - node.args.length

  for e in node.seq
    if e.name
      if ctx.words[e.name] != undefined
        throw "redefined: #{e.name}"
      ctx.words[e.name] = e.val

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
  blockEval new ast.NodeBlock [], seq



