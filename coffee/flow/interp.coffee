interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


lastArgs = (n, ctx) ->
  l = ctx.values.length
  if l < n then throw "no enough args"
  [ctx.values.slice(0,l-n), ctx.values.slice(l-n)]

lastArgs1 = (ctx) -> lastArgs 1, ctx
lastArgs2 = (ctx) -> lastArgs 2, ctx
lastArgs3 = (ctx) -> lastArgs 3, ctx


buildinWords = {
  "+": (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a+b]
  "-": (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a-b]
  "*": (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a*b]
  "/": (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a/b]

  '=':  (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a==b]
  '<':  (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a<b]
  '>':  (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a>b]
  '<=': (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a<=b]
  '>=': (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a>=b]

  'not': (ctx) -> [remain, [a]] = lastArgs1(ctx); remain.concat [!a]
  'and': (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a&&b]
  'or':  (ctx) -> [remain, [a,b]] = lastArgs2(ctx); remain.concat [a||b]

  'if': (ctx) ->
    [remain, [cond, whenTrue, whenFalse]] = lastArgs3(ctx)

    if !(whenTrue instanceof ast.NodeBlock)
      throw "whenTrue is not a block: #{pp whenTrue}"
    if !(whenFalse instanceof ast.NodeBlock)
      throw "whenFalse is not a block: #{pp whenFalse}"

    if cond
      remain.concat blockEval whenTrue, ctx
    else
      remain.concat blockEval whenFalse, ctx
}


class Context
  constructor: (@parent, @curBlock, @name) ->
    @values = []
    @words = {}
    if @name
      @words[@name] = @curBlock

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

  else if word instanceof Function
    v = word(ctx)

  else if word != undefined
    v = word

  else
    v = eval(node.name)(ctx.values...)

  v


blockEval = (node, parentCtx, name) ->
  ctx = new Context parentCtx, node, name

  for e in node.seq
    if e.name
      if ctx.words[e.name] != undefined
        throw "redefined: #{e.name}"
      ctx.words[e.name] = e.val

  for e in node.seq
    v = elemEval e, ctx

    if v instanceof Array
      for ve in v
        ctx.values.push ve
    else
      ctx.values.push v
  ctx.values
  


interp.eval = (seq) ->
  blockEval new ast.NodeBlock [], seq



