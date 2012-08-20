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
  constructor: (@parent=null) ->
    @ret = new ast.Block [], [], []


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
  b = seqCurryBlock blkElem, parentCtx, blkElem.val.args.length
  ctx = new Context parentCtx
  retSeq = ctx.ret.seq
  for e in b.seq
    if e.val instanceof ast.Word
      v = wordEval1 e, ctx, wordCtx
      if v instanceof ast.Block && v.type=="EVAL"
        for ve in v.seq
          retSeq.push ve
      else
        retSeq.push new ast.Elem v
    else
      retSeq.push e
  ctx.ret


interp.eval = (blk) ->
  blockEval blk, null




