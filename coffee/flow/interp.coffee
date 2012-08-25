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

  eval: (elem, blk, retSeq, callStack) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", elem.srcInfo.pos, blk.srcInfo.src
    retSeq.length = retSeq.length-@numArgs
    args = [blk, retSeq, callStack].concat args
    @fn args...

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (block, retSeq, callStack, a, b) -> a.val+b.val
  "-":    bw 2, (block, retSeq, callStack, a, b) -> a.val-b.val
  "*":    bw 2, (block, retSeq, callStack, a, b) -> a.val*b.val
  "/":    bw 2, (block, retSeq, callStack, a, b) -> a.val/b.val

  "=":    bw 2, (block, retSeq, callStack, a, b) -> a.val==b.val
  "<":    bw 2, (block, retSeq, callStack, a, b) -> a.val<b.val
  ">":    bw 2, (block, retSeq, callStack, a, b) -> a.val>b.val
  "<=":   bw 2, (block, retSeq, callStack, a, b) -> a.val<=b.val
  ">=":   bw 2, (block, retSeq, callStack, a, b) -> a.val>=b.val

  "not":  bw 1, (block, retSeq, callStack, a)    -> !a.val
  "and":  bw 2, (block, retSeq, callStack, a, b) -> a.val&&b.val
  "or":   bw 2, (block, retSeq, callStack, a, b) -> a.val||b.val

  "if":   bw 3, (block, retSeq, callStack, cond, whenTrue, whenFals) ->
    if typeof cond.val != 'boolean'
      err "expect a boolean: #{cond.val}", cond.srcInfo.pos, block.srcInfo.src
    if !(whenTrue.val instanceof ast.Block)
      err "expect a block: #{whenTrue.val}", whenTrue.srcInfo.pos, block.srcInfo.src
    if !(whenFals.val instanceof ast.Block)
      err "expect a block: #{whenFals.val}", whenFals.srcInfo.pos, block.srcInfo.src

    if cond.val
      blockEval whenTrue, retSeq, callStack
    else
      blockEval whenFals, retSeq, callStack
    undefined

  "do":   bw 1, (block, retSeq, callStack, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blockEval blkElem, retSeq, callStack
    undefined

  "get":  bw 2, (block, retSeq, callStack, blkElem, nameElem) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
    name = nameElem.val
    [found, elem] = blk.getElem name
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{blk}", nameElem.srcInfo.pos, ctx.block.srcInfo.src

  "set":  bw 3, (block, retSeq, callStack, blkElem, elem, nameElem) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
    name = nameElem.val
    blk.setElem name, elem

  "len":  bw 1, (block, retSeq, callStack, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.len()

  "num-words": bw 1, (block, retSeq, callStack, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.numWords

  "num-elems": bw 1, (block, retSeq, callStack, blkElem) ->
    if !(blkElem.val instanceof ast.Block)
      err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
    blkElem.val.numElems()

  "slice":  bw 3, (block, retSeq, callStack, blkElem, start, end) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
    blk.slice start.val, end.val

  "join":   bw 2, (block, retSeq, callStack, a, b) ->
    if !(a.val instanceof ast.Block)
      err "expect a block: #{a.val}", a.val.srcInfo.pos, a.val.srcInfo.src
    if !(b.val instanceof ast.Block)
      err "expect a block: #{b.val}", b.val.srcInfo.pos, b.val.srcInfo.src
    a.val.join b.val

  "unshift":  bw 2, (block, retSeq, callStack, blkElem, elem) ->
    blk = blkElem.val
    if !(blk instanceof ast.Block)
      err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
    blk.unshift elem
}


getArgWords = (name, callStack) ->
  for i in [callStack.length...0]
    argWords = callStack[i-1]
    w = argWords[name]
    if w != undefined
      return w
  null


wordEval = (wordElem, blk, callStack) ->
  if wordElem.val.val == null
    w = getArgWords wordElem.val.name, callStack
    if w != null
      val = w.val
    else
      w = buildinWords[wordElem.val.name]
      if w != undefined
        val = w
      else
        err "word:#{wordElem.val.name} not defined", wordElem.srcInfo.pos, blk.srcInfo.src
  else
    val = wordElem.val.val.val
  val


valEval = (val, e, blk, retSeq, callStack) ->
  if val instanceof ast.Block && val.elemType == "EVAL"
    blockEval new ast.Elem(val, null, val.srcInfo), retSeq, callStack
  else if val instanceof BuildinWord
    v = val.eval e, blk, retSeq, callStack
    if v != undefined
      valEval v, e, blk, retSeq, callStack
  else
    retSeq.push new ast.Elem val, null, e.srcInfo


blockEval = (blkElem, retSeq, callStack) ->
  blk = blkElem.val

  l = blk.args.length
  if l > 0
    args = retSeq.slice -l
    argWords = {}
    for i in [0..l-1]
      a = blk.args[i]
      v = args[i]
      argWords[a.name] = v
    callStack = callStack.concat [argWords]
    retSeq.length = retSeq.length-l

  for e in blk.seq
    if e.val instanceof ast.Word
      val = wordEval e, blk, callStack
    else
      val = e.val
    valEval val, e, blk, retSeq, callStack


interp.eval = (blkElem) ->
  blkElem.val.linkWordsVal()
  retSeq = []
  blockEval blkElem, retSeq, []
  retSeq













