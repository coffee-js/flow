interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


class Context
  constructor: (@block, @parent=null) ->
    @ret = new ast.Block [], [], []


getArgs = (elem, n, ctx) ->
  blk = ctx.block
  l = ctx.ret.seq.length
  if l < n
    if ctx.parent == null
      err "no enough args in context:#{ctx}", elem.srcInfo.pos, blk.srcInfo.src
    else
      args0 = getArgs elem, n-l, ctx.parent
  p = if l-n < 0 then 0 else l-n
  args = ctx.ret.seq.slice p
  if args0 != undefined
    args = args0.concat args
  ctx.ret.seq.length = p
  args


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (elem, ctx) ->
    args = getArgs elem, @numArgs, ctx
    a = [ctx].concat args
    @fn a...

blockWrap = (seq, wordSeq=[]) ->
  new ast.Block [], wordSeq, seq

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (ctx, a, b) -> a.val+b.val
  "-":    bw 2, (ctx, a, b) -> a.val-b.val
  "*":    bw 2, (ctx, a, b) -> a.val*b.val
  "/":    bw 2, (ctx, a, b) -> a.val/b.val

  "=":    bw 2, (ctx, a, b) -> a.val==b.val
  "<":    bw 2, (ctx, a, b) -> a.val<b.val
  ">":    bw 2, (ctx, a, b) -> a.val>b.val
  "<=":   bw 2, (ctx, a, b) -> a.val<=b.val
  ">=":   bw 2, (ctx, a, b) -> a.val>=b.val

  "not":  bw 1, (ctx, a)    -> !a.val
  "and":  bw 2, (ctx, a, b) -> a.val&&b.val
  "or":   bw 2, (ctx, a, b) -> a.val||b.val

  "if":   bw 3, (ctx, cond, whenTrue, whenFals) ->
    blk = ctx.block
    if typeof(cond.val) != 'boolean'
      err "cond is not a boolean: #{cond.val}", cond.srcInfo.pos, blk.srcInfo.src
    if !(whenTrue.val instanceof ast.Block)
      err "whenTrue is not a block: #{whenTrue.val}", whenTrue.srcInfo.pos, blk.srcInfo.src
    if !(whenFals.val instanceof ast.Block)
      err "whenFals is not a block: #{whenFals.val}", whenFals.srcInfo.pos, blk.srcInfo.src

    if cond.val
      blockEval whenTrue, ctx
    else
      blockEval whenFals, ctx

  "do":   bw 1, (ctx, blk) ->
    if !(blk.val instanceof ast.Block)
      err "#{blk.val} is not a block", blk.val.srcInfo.pos, blk.val.srcInfo.src
    blockEval blk, ctx
}


wordEval = (wordElem, ctx) ->
  name = wordElem.val.name
  elem = ctx.block.getWord name

  if elem != null
    if elem.val instanceof ast.Word
      wordEval elem, ctx
    else
      elem.val
  else if buildinWords[name] != undefined
    buildinWords[name].eval wordElem, ctx
  else if name.match /^js\//i
    args = []
    for e in ctx.ret.seq
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = name.slice(3) + "(" + a + ")"
    v = eval jsCode
    if v == undefined
      blockWrap []
    else
      v
  else
    err "word:\"#{name}\" not defined", wordElem.srcInfo.pos, ctx.block.srcInfo.src


seqCurryBlock = (blkElem, ctx, n) ->
  if n < 1
    return blkElem.val.clone()
  blk = blkElem.val
  if n > blk.args.length
    err "n > blk.args.length", blkElem.srcInfo.pos, blk.srcInfo.src
  args = getArgs blkElem, n, ctx
  argWords = {}
  for i in [0..n-1]
    a = blk.args[i]
    v = args[i]
    argWords[a.name] = v
  blk.curry argWords


blockEval = (blkElem, parentCtx) ->
  blk = seqCurryBlock blkElem, parentCtx, blkElem.val.args.length
  ctx = new Context blk, parentCtx
  retSeq = ctx.ret.seq
  for e in blk.seq
    v = e.val
    if e.val instanceof ast.Word
      v = wordEval e, ctx
    if v instanceof ast.Block
      if v.elemType == "EVAL"
        v = blockEval (new ast.Elem v, null, v.srcInfo), ctx
        for ve in v.seq
          retSeq.push ve
      else
        retSeq.push (new ast.Elem v, null, v.srcInfo)
    else
      retSeq.push (new ast.Elem v, null, e.srcInfo)
  ctx.ret


interp.eval = (blk) ->
  blockEval blk, new Context(blk, null)




