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


getArgs = (elem, n, ctx, blk) ->
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


wordEval = (wordElem, block, ctx) ->
  name = wordElem.val.name

  [word, wordCtx1] = wordCtx.getWord name
  if word instanceof BuildinWord
    word.eval wordElem, retCtx, wordCtx
  else if word != null && word.val != null
    if      word.val instanceof ast.Block
      if evalBlock
        blockEval word, retCtx, wordCtx1
      else
        blockWrap [new ast.Elem word.val, null, word.srcInfo.pos]
    else if word.val instanceof ast.Word
      wordEval  word, retCtx, wordCtx1
    else
      word.val
  else if name.match /^js\//i
    args = []
    for e in retCtx.retBlk.seq
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
    err "word:\"#{name}\" not defined", wordElem.srcInfo.pos, wordCtx.block.srcInfo.src


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
      v = wordEval e, b, ctx
      if v instanceof ast.Block
        for ve in v.seq
          retSeq.push ve
      else
        retSeq.push new ast.Elem v
    else
      retSeq.push e
  ctx.ret


interp.eval = (blk) ->
  blockEval blk, new Context(null)




