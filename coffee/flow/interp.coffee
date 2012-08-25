interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if pos != null && src != null
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (elem, blk, stack) ->
    args = stack.slice(-@numArgs)
    if args.length < @numArgs
      err "no enough args in seq:#{stack}", elem.srcInfo.pos, blk.srcInfo.src
    stack.length = stack.length-@numArgs
    args = [blk, stack].concat args
    @fn args...

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (blk, stack, a, b) -> a.val+b.val
  "-":    bw 2, (blk, stack, a, b) -> a.val-b.val
  "*":    bw 2, (blk, stack, a, b) -> a.val*b.val
  "/":    bw 2, (blk, stack, a, b) -> a.val/b.val

  "=":    bw 2, (blk, stack, a, b) -> a.val==b.val
  "<":    bw 2, (blk, stack, a, b) -> a.val<b.val
  ">":    bw 2, (blk, stack, a, b) -> a.val>b.val
  "<=":   bw 2, (blk, stack, a, b) -> a.val<=b.val
  ">=":   bw 2, (blk, stack, a, b) -> a.val>=b.val

  "not":  bw 1, (blk, stack, a)    -> !a.val
  "and":  bw 2, (blk, stack, a, b) -> a.val&&b.val
  "or":   bw 2, (blk, stack, a, b) -> a.val||b.val

  "if":   bw 3, (blk, stack, cond, whenTrue, whenFals) ->
    if typeof(cond.val) != 'boolean'
      err "expect a boolean: #{cond.val}", cond.srcInfo.pos, blk.srcInfo.src
    if !(whenTrue.val instanceof ast.Block)
      err "expect a block: #{whenTrue.val}", whenTrue.srcInfo.pos, blk.srcInfo.src
    if !(whenFals.val instanceof ast.Block)
      err "expect a block: #{whenFals.val}", whenFals.srcInfo.pos, blk.srcInfo.src

    if cond.val
      blockEval whenTrue, stack
    else
      blockEval whenFals, stack
    undefined

  "do":   bw 1, (blk, stack, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blockEval blkElem, stack
    undefined
}


wordEval = (wordElem, blk) ->
  if wordElem.val.val == null
    w = buildinWords[wordElem.val.name]
    if w != undefined
      val = w
    else
      err "word:#{wordElem.val.name} not defined", wordElem.srcInfo.pos, blk.srcInfo.src
  else
    val = wordElem.val.val.val
  val


valEval = (val, e, blk, stack) ->
  if val instanceof ast.Block && val.elemType == "EVAL"
    blockEval new ast.Elem(val, null, val.srcInfo), stack
  else if val instanceof BuildinWord
    v = val.eval(e, blk, stack)
    if v != undefined
      valEval v, e, blk, stack
  else
    stack.push new ast.Elem val, null, e.srcInfo


blockEval = (blkElem, stack) ->
  blk = blkElem.val
  for e in blk.seq
    if e.val instanceof ast.Word
      val = wordEval e, blk
    else
      val = e.val
    valEval val, e, blk, stack


interp.eval = (blkElem) ->
  blkElem.val.linkWordsVal()
  stack = []
  blockEval blkElem, stack
  stack













