interp = exports
ast = require "./ast"


log = (s) -> console.log s


getArgs = (e, n, ctx) ->
  l = ctx.retBlk.seq.length
  if l < n
    if ctx.parent == null
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} no enough args in context:#{ctx}"
    else
      args0 = getArgs e, n-l, ctx.parent
  p = if l-n < 0 then 0 else l-n
  args = ctx.retBlk.seq.slice p
  if args0 != undefined
    args = args0.concat args
  ctx.retBlk.seq.length = p
  args


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (e, ctx) ->
    args = getArgs e, @numArgs, ctx
    a = [e, ctx].concat args
    @fn a...


bw = ->
  new BuildinWord arguments...

ne = (a) ->
  new ast.Block [], (a.map (v) -> new ast.Elem null, v)


buildinWords = {
  ";":    bw 0, (e, ctx) -> ctx.retBlk.seq.length = 0; ne []

  "+":    bw 2, (e, ctx, a, b) -> a.val+b.val
  "-":    bw 2, (e, ctx, a, b) -> a.val-b.val
  "*":    bw 2, (e, ctx, a, b) -> a.val*b.val
  "/":    bw 2, (e, ctx, a, b) -> a.val/b.val

  '=':    bw 2, (e, ctx, a, b) -> a.val==b.val
  '<':    bw 2, (e, ctx, a, b) -> a.val<b.val
  '>':    bw 2, (e, ctx, a, b) -> a.val>b.val
  '<=':   bw 2, (e, ctx, a, b) -> a.val<=b.val
  '>=':   bw 2, (e, ctx, a, b) -> a.val>=b.val

  'not':  bw 1, (e, ctx, a)    -> !a.val
  'and':  bw 2, (e, ctx, a, b) -> a.val&&b.val
  'or':   bw 2, (e, ctx, a, b) -> a.val||b.val

  'if':   bw 3, (e, ctx, cond, whenTrue, whenFals) ->
    if typeof(cond.val) != 'boolean'
      [line, col] = ctx.source().lineCol cond.pos
      throw "#{line}:#{col} cond is not a boolean: #{cond.val}"
    if !(whenTrue.val instanceof ast.Block)
      [line, col] = ctx.source().lineCol whenTrue.pos
      throw "#{line}:#{col} whenTrue is not a block: #{whenTrue.val}"
    if !(whenFals.val instanceof ast.Block)
      [line, col] = ctx.source().lineCol whenFals.pos
      throw "#{line}:#{col} whenFals is not a block: #{whenFals.val}"

    if cond.val
      blockEval whenTrue, ctx
    else
      blockEval whenFals, ctx

  'do':   bw 1, (e, ctx, blk) ->
    if !(blk.val instanceof ast.Block)
      [line, col] = ctx.source().lineCol e.pos
      throw "#{line}:#{col} #{blk.val} is not a block"
    blockEval blk, ctx
}


class Context
  constructor: (@parent, @block) ->
    @retBlk = new ast.Block [], []

  source: ->
    @block.src

  getWord: (name) ->
    word = @block.words[name]

    if word != undefined
      [word, @]
    else if @parent
      @parent.getWord name
    else if buildinWords[name] != undefined
      [buildinWords[name], null]
    else
      [null, null]


wordEval = (wordElem, ctx) ->
  [word, wordCtx] = ctx.getWord wordElem.val.name, ctx.block
  if word instanceof BuildinWord
    word.eval wordElem, ctx
  else if word != null && word.val != null
    if      word.val instanceof ast.Block
      blockEval word, ctx
    else if word.val instanceof ast.Word
      wordEval  word, ctx
    else
      word.val
  else
    args = []
    for e in ctx.retBlk.seq
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = wordElem.val.name + "(" + a + ")"
    eval jsCode


seqCurryBlock = (blkElem, ctx, l) ->
  if l < 1
    return blkElem.val
  blk = blkElem.val
  if l > blk.args.length
    [line, col] = ctx.source().lineCol blkElem.pos
    throw "#{line}:#{col} l > blk.args.length"
  args = getArgs blkElem, l, ctx
  argWords = {}

  for i in [0..l-1]
    a = blk.args[i]
    v = args[l-i-1]
    argWords[a.name] = v
  b = blk.curry argWords
  b


blockEval = (blkElem, parentContext) ->
  b = seqCurryBlock blkElem, parentContext, blkElem.val.args.length
  ctx = new Context parentContext, b

  for e in ctx.block.seq
    if e.val instanceof ast.Word
      v = wordEval e, ctx
      if v instanceof ast.Block
        for ve in v.seq
          ctx.retBlk.seq.push ve
      else
        ctx.retBlk.seq.push new ast.Elem null, v
    else
      ctx.retBlk.seq.push e
  ctx.retBlk


interp.eval = (blk) ->
  blockEval blk, null















