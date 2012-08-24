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

  "do":   bw 1, (ctx, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "#{blkElem.val} is not a block", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blockEval blkElem, ctx

  "slice": bw 3, (ctx, blkElem, start, end) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "#{blk} is not a block", blk.srcInfo.pos, blk.srcInfo.src
    blk.slice start.val, end.val

  "num-words": bw 1, (ctx, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "#{blkElem.val} is not a block", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.numWords

  "len": bw 1, (ctx, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "#{blkElem.val} is not a block", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.seq.length

  "num-elems": bw 1, (ctx, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "#{blkElem.val} is not a block", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.numElems()

  "join": bw 2, (ctx, a, b) ->
    if !(a.val instanceof ast.Block)
      err "#{a.val} is not a block", a.val.srcInfo.pos, a.val.srcInfo.src
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.srcInfo.pos, b.val.srcInfo.src
    a.val.join b.val, ctx.block

  "unshift": bw 2, (ctx, blkElem, elem) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "#{blk} is not a block", blk.srcInfo.pos, blk.srcInfo.src
    blk.unshift elem
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
      new ast.Block [], [], []
    else
      v
  else
    err "word:\"#{name}\" not defined", wordElem.srcInfo.pos, ctx.block.srcInfo.src


readElemInBlock = (wordElem, ctx) ->
  [blkElem] = getArgs wordElem, 1, ctx
  blk = blkElem.val
  if !(blk instanceof ast.Block)
    err "expect a block: #{blk}", blkElem.srcInfo.pos, ctx.block.srcInfo.src
  name = wordElem.val.name.slice 0,-1
  [found, elem] = blk.getElem name
  if found
    elem.val
  else
    err "no elem named:#{n} in block #{blk}", wordElem.srcInfo.pos, ctx.block.srcInfo.src


writeElemInBlock = (wordElem, ctx) ->
  [blkElem, elem] = getArgs wordElem, 2, ctx
  blk = blkElem.val
  if !(blk instanceof ast.Block)
    err "expect a block: #{blk}", blkElem.srcInfo.pos, ctx.block.srcInfo.src
  name = wordElem.val.name.slice 1
  blk.setElem name, elem


wordEval1 = (wordElem, ctx) ->
  name = wordElem.val.name
  if      name.match /.+>$/
    readElemInBlock  wordElem, ctx
  else if name.match /^>.+/
    writeElemInBlock wordElem, ctx
  else
    wordEval wordElem, ctx


seqCurryBlock = (blkElem, ctx, n) ->
  if n < 1
    return blkElem.val
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
    if e.val instanceof ast.Word
      val = wordEval1 e, ctx
    else
      val = e.val
    
    if (val instanceof ast.Block) && (val.elemType == "EVAL")
      val = blockEval (new ast.Elem val, null, val.srcInfo), ctx
      for ve in val.seq
        retSeq.push ve
    else
      retSeq.push (new ast.Elem val, null, e.srcInfo)
  ctx.ret


interp.eval = (blk) ->
  blockEval blk, new Context(blk, null)
















