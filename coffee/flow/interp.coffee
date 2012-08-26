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

  eval: (elem, retSeq, wordEnv, block) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", elem.srcInfo.pos, block.srcInfo.src
    retSeq.length = retSeq.length-@numArgs
    args = [retSeq, wordEnv, block].concat args
    @fn args...

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val+b.val
  "-":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val-b.val
  "*":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val*b.val
  "/":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val/b.val

  "=":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val==b.val
  "<":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val<b.val
  ">":    bw 2, (retSeq, wordEnv, block, a, b) -> a.val>b.val
  "<=":   bw 2, (retSeq, wordEnv, block, a, b) -> a.val<=b.val
  ">=":   bw 2, (retSeq, wordEnv, block, a, b) -> a.val>=b.val

  "not":  bw 1, (retSeq, wordEnv, block, a)    -> !a.val
  "and":  bw 2, (retSeq, wordEnv, block, a, b) -> a.val&&b.val
  "or":   bw 2, (retSeq, wordEnv, block, a, b) -> a.val||b.val

  "if":   bw 3, (retSeq, wordEnv, block, cond, whenTrue, whenFals) ->
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

  "do":   bw 1, (retSeq, wordEnv, block, elem) ->
    b = elem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", elem.srcInfo.pos, block.srcInfo.src
    blockEval b.block, retSeq, b.wordEnv
    undefined

  "get":  bw 2, (retSeq, wordEnv, block, bElem, nameElem) ->
    b = bElem.val
    name = nameElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    
    [found, elem] = b.block.getElem name
    if found
      if elem.val instanceof ast.Block
        bWordEnv = blockWordEnv b.block, {}, b.wordEnv
        new Closure elem.val, blockWordEnv(elem.val, {}, bWordEnv)
      else
        elem.val
    else
      err "no elem named:#{name} in block #{b}", nameElem.srcInfo.pos, block.srcInfo.src

  "set":  bw 3, (retSeq, wordEnv, block, bElem, elem, nameElem) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    name = nameElem.val
    b.block.setElem name, elem

  "len":  bw 1, (retSeq, wordEnv, block, bElem) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{bElem.val}", bElem.srcInfo.pos, block.srcInfo.src
    b.block.len()

  "num-words": bw 1, (retSeq, wordEnv, block, bElem) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    b.block.numWords

  "num-elems": bw 1, (retSeq, wordEnv, block, bElem) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    b.block.numElems()

  "slice":  bw 3, (retSeq, wordEnv, block, bElem, start, end) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    b.block.slice start.val, end.val

  "join":   bw 2, (retSeq, wordEnv, block, a, b) ->
    if !(a.val instanceof Closure)
      err "expect a block: #{a.val}", a.srcInfo.pos, block.srcInfo.src
    if !(b.val instanceof Closure)
      err "expect a block: #{b.val}", b.srcInfo.pos, block.srcInfo.src
    a.val.block.join b.val.block

  "unshift":  bw 2, (retSeq, wordEnv, block, bElem, elem) ->
    b = bElem.val
    if !(b instanceof Closure)
      err "expect a block: #{b}", bElem.srcInfo.pos, block.srcInfo.src
    b.block.unshift elem
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


valEval = (val, e, retSeq, wordEnv, block) ->
  if val instanceof Closure && val.block.elemType == "EVAL"
    blockEval val.block, retSeq, val.wordEnv
  else if val instanceof BuildinWord
    v = val.eval e, retSeq, wordEnv, block
    if v != undefined
      valEval v, e, retSeq, wordEnv, block
  else
    if val instanceof ast.Block
      val = new Closure val, wordEnv
    retSeq.push new ast.Elem val, null, e.srcInfo


blockWordEnv = (block, argWords, preWordEnv) ->
  words = {}
  wordEnv = [words].concat preWordEnv

  for a in block.args
    words[a.name] = argWords[a.name]

  for name of block.words
    w = block.words[name]
    if w.val instanceof ast.Block
      words[name] = new Closure w.val, wordEnv
    else
      words[name] = w.val
  wordEnv


seqCurryBlock = (block, retSeq, n) ->
  if n < 1
    return {}
  argWords = {}
  if n > block.args.length
    err "block:#{block} max args num is #{block.args.length}", block.srcInfo.pos, block.srcInfo.src
  args = retSeq.slice -n
  for i in [0..n-1]
    a = block.args[i]
    w = args[i]
    argWords[a.name] = w.val
  retSeq.length = retSeq.length-n
  argWords


blockEval = (block, retSeq, preWordEnv) ->
  argWords = seqCurryBlock block, retSeq, block.args.length
  wordEnv = blockWordEnv block, argWords, preWordEnv

  for e in block.seq
    if      e.val instanceof ast.Word
      val = wordEval e, wordEnv
      if val == undefined
        err "word:#{e.val.name} not defined", e.srcInfo.pos, block.srcInfo.src
    else if e.val instanceof ast.Block
      val = new Closure e.val, wordEnv
    else
      val = e.val
    valEval val, e, retSeq, wordEnv, block


interp.eval = (blockElem) ->
  retSeq = []
  blockEval blockElem.val, retSeq, []
  retSeq













