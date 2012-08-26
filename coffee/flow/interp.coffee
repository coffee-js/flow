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


class Closure
  constructor: (@block, @wordEnv) ->


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (elem, blk, retSeq) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", elem.srcInfo.pos, blk.srcInfo.src
    retSeq.length = retSeq.length-@numArgs
    args = [blk, retSeq].concat args
    @fn args...

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (block, retSeq, a, b) -> a.val+b.val
  "-":    bw 2, (block, retSeq, a, b) -> a.val-b.val
  "*":    bw 2, (block, retSeq, a, b) -> a.val*b.val
  "/":    bw 2, (block, retSeq, a, b) -> a.val/b.val

  "=":    bw 2, (block, retSeq, a, b) -> a.val==b.val
  "<":    bw 2, (block, retSeq, a, b) -> a.val<b.val
  ">":    bw 2, (block, retSeq, a, b) -> a.val>b.val
  "<=":   bw 2, (block, retSeq, a, b) -> a.val<=b.val
  ">=":   bw 2, (block, retSeq, a, b) -> a.val>=b.val

  "not":  bw 1, (block, retSeq, a)    -> !a.val
  "and":  bw 2, (block, retSeq, a, b) -> a.val&&b.val
  "or":   bw 2, (block, retSeq, a, b) -> a.val||b.val

  "if":   bw 3, (block, retSeq, cond, whenTrue, whenFals) ->
    if typeof cond.val != 'boolean'
      err "expect a boolean: #{cond.val}", cond.srcInfo.pos, block.srcInfo.src
    if !(whenTrue.val instanceof Closure)
      err "expect a block: #{whenTrue.val}", whenTrue.srcInfo.pos, block.srcInfo.src
    if !(whenFals.val instanceof Closure)
      err "expect a block: #{whenFals.val}", whenFals.srcInfo.pos, block.srcInfo.src

    if cond.val
      blockEval whenTrue.val.block, retSeq, whenTrue.val.wordEnv
    else
      blockEval whenFals.val.block, retSeq, whenFals.val.wordEnv
    undefined

  "do":   bw 1, (block, retSeq, elem) ->
    b = elem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", elem.srcInfo.pos, block.srcInfo.src
    blockEval b.block, retSeq, b.wordEnv
    undefined

  # "get":  bw 2, (block, retSeq, blkElem, nameElem) ->
  #   blk = blkElem.val
  #   if !(blk instanceof ast.Block)
  #     err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
  #   name = nameElem.val
  #   [found, elem] = blk.getElem name
  #   if found
  #     elem.val
  #   else
  #     err "no elem named:#{name} in block #{blk}", nameElem.srcInfo.pos, blk.srcInfo.src

  # "set":  bw 3, (block, retSeq, blkElem, elem, nameElem) ->
  #   blk = blkElem.val
  #   if !(blk instanceof ast.Block)
  #     err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
  #   name = nameElem.val
  #   blk.setElem name, elem

  # "len":  bw 1, (block, retSeq, blkElem) ->
  #   if !(blkElem.val instanceof ast.Block)
  #     err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
  #   blkElem.val.len()

  # "num-words": bw 1, (block, retSeq, blkElem) ->
  #   if !(blkElem.val instanceof ast.Block)
  #     err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
  #   blkElem.val.numWords

  # "num-elems": bw 1, (block, retSeq, blkElem) ->
  #   if !(blkElem.val instanceof ast.Block)
  #     err "expect a block: #{blkElem.val}", blkElem.val.srcInfo.pos, blkElem.val.srcInfo.src
  #   blkElem.val.numElems()

  # "slice":  bw 3, (block, retSeq, blkElem, start, end) ->
  #   blk = blkElem.val
  #   if !(blk instanceof ast.Block)
  #     err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
  #   blk.slice start.val, end.val

  # "join":   bw 2, (block, retSeq, a, b) ->
  #   if !(a.val instanceof ast.Block)
  #     err "expect a block: #{a.val}", a.val.srcInfo.pos, a.val.srcInfo.src
  #   if !(b.val instanceof ast.Block)
  #     err "expect a block: #{b.val}", b.val.srcInfo.pos, b.val.srcInfo.src
  #   a.val.join b.val

  # "unshift":  bw 2, (block, retSeq, blkElem, elem) ->
  #   blk = blkElem.val
  #   if !(blk instanceof ast.Block)
  #     err "expect a block: #{blk}", blk.srcInfo.pos, blk.srcInfo.src
  #   blk.unshift elem
}


wordInEnv = (word, wordEnv) ->
  name = word.name
  for i in [0...wordEnv.length]
    words = wordEnv[i]
    w = words[name]
    if w != undefined
      if w instanceof ast.Word
        w = wordInEnv w, wordEnv.slice(i)
      break
  w


wordEval = (wordElem, wordEnv) ->
  name = wordElem.val.name
  w = wordInEnv wordElem.val, wordEnv
  if w == undefined
    w = buildinWords[name]
  w


valEval = (val, e, blk, retSeq, wordEnv) ->
  if val instanceof Closure && val.block.elemType == "EVAL"
    blockEval val.block, retSeq, val.wordEnv
  else if val instanceof BuildinWord
    v = val.eval e, blk, retSeq
    if v != undefined
      valEval v, e, blk, retSeq, wordEnv
  else
    retSeq.push new ast.Elem val, null, e.srcInfo


blockEval = (blk, retSeq, preWordEnv) ->
  words = {}
  l = blk.args.length
  if l > 0
    args = retSeq.slice -l
    for i in [0..l-1]
      a = blk.args[i]
      w = args[i]
      words[a.name] = w.val
    retSeq.length = retSeq.length-l

  wordEnv = [words].concat preWordEnv
  for name of blk.words
    w = blk.words[name]
    if w.val instanceof ast.Block
      words[name] = new Closure w.val, wordEnv
    else
      words[name] = w.val

  for e in blk.seq
    if      e.val instanceof ast.Word
      val = wordEval e, wordEnv
      if val == undefined
        err "word:#{e.val.name} not defined", e.srcInfo.pos, blk.srcInfo.src
    else if e.val instanceof ast.Block
      val = new Closure e.val, wordEnv
    else
      val = e.val
    valEval val, e, blk, retSeq, wordEnv


interp.eval = (blkElem) ->
  retSeq = []
  blockEval blkElem.val, retSeq, []
  retSeq













