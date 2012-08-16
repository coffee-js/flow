interp = exports
ast = require "./ast"


log = (s) -> console.log s


getArgs = (elem, n, seqCtx, blk) ->
  l = seqCtx.retBlk.seq.length
  if l < n
    if seqCtx.parent == null
      [line, col] = blk.src.lineCol elem.pos
      throw "#{line}:#{col} no enough args in context:#{seqCtx}"
    else
      args0 = getArgs elem, n-l, seqCtx.parent
  p = if l-n < 0 then 0 else l-n
  args = seqCtx.retBlk.seq.slice p
  if args0 != undefined
    args = args0.concat args
  seqCtx.retBlk.seq.length = p
  args


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (elem, seqCtx, wordCtx) ->
    args = getArgs elem, @numArgs, seqCtx, wordCtx
    a = [seqCtx, wordCtx].concat args
    @fn a...


bw = ->
  new BuildinWord arguments...

ne = (a) ->
  new ast.Block [], (a.map (v) -> new ast.Elem null, v)


buildinWords = {
  ";":    bw 0, (seqCtx, wordCtx) -> seqCtx.retBlk.seq.length = 0; ne []

  "+":    bw 2, (seqCtx, wordCtx, a, b) -> a.val+b.val
  "-":    bw 2, (seqCtx, wordCtx, a, b) -> a.val-b.val
  "*":    bw 2, (seqCtx, wordCtx, a, b) -> a.val*b.val
  "/":    bw 2, (seqCtx, wordCtx, a, b) -> a.val/b.val

  '=':    bw 2, (seqCtx, wordCtx, a, b) -> a.val==b.val
  '<':    bw 2, (seqCtx, wordCtx, a, b) -> a.val<b.val
  '>':    bw 2, (seqCtx, wordCtx, a, b) -> a.val>b.val
  '<=':   bw 2, (seqCtx, wordCtx, a, b) -> a.val<=b.val
  '>=':   bw 2, (seqCtx, wordCtx, a, b) -> a.val>=b.val

  'not':  bw 1, (seqCtx, wordCtx, a)    -> !a.val
  'and':  bw 2, (seqCtx, wordCtx, a, b) -> a.val&&b.val
  'or':   bw 2, (seqCtx, wordCtx, a, b) -> a.val||b.val

  'if':   bw 3, (seqCtx, wordCtx, cond, whenTrue, whenFals) ->
    b = wordCtx.block
    if typeof(cond.val) != 'boolean'
      [line, col] = b.src.lineCol cond.pos
      throw "#{line}:#{col} cond is not a boolean: #{cond.val}"
    if !(whenTrue.val instanceof ast.Block)
      [line, col] = b.src.lineCol whenTrue.pos
      throw "#{line}:#{col} whenTrue is not a block: #{whenTrue.val}"
    if !(whenFals.val instanceof ast.Block)
      [line, col] = b.src.lineCol whenFals.pos
      throw "#{line}:#{col} whenFals is not a block: #{whenFals.val}"

    if cond.val
      blockEval whenTrue, seqCtx, wordCtx
    else
      blockEval whenFals, seqCtx, wordCtx

  'do':   bw 1, (seqCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      [line, col] = b.src.lineCol e.pos
      throw "#{line}:#{col} #{b.val} is not a block"
    blockEval b, seqCtx, wordCtx
}


class WordContext
  constructor: (@block, @parent) ->

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


class SeqContext
  constructor: (@parent=null) ->
    @retBlk = new ast.Block [], []


wordEval = (wordElem, seqCtx, wordCtx) ->
  [word, wordCtx1] = wordCtx.getWord wordElem.val.name
  if word instanceof BuildinWord
    word.eval wordElem, seqCtx, wordCtx
  else if word != null && word.val != null
    if      word.val instanceof ast.Block
      blockEval word, seqCtx, wordCtx1
    else if word.val instanceof ast.Word
      wordEval  word, seqCtx, wordCtx1
    else
      word.val
  else
    args = []
    for e in seqCtx.retBlk.seq
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = wordElem.val.name + "(" + a + ")"
    eval jsCode


seqCurryBlock = (blkElem, seqCtx, l) ->
  if l < 1
    return blkElem.val
  blk = blkElem.val
  if l > blk.args.length
    [line, col] = blk.src.lineCol blkElem.pos
    throw "#{line}:#{col} l > blk.args.length"
  args = getArgs blkElem, l, seqCtx
  argWords = {}

  for i in [0..l-1]
    a = blk.args[i]
    v = args[l-i-1]
    argWords[a.name] = v
  b = blk.curry argWords
  b


blockEval = (blkElem, parentSeqCtx, parentWordCtx) ->
  b = seqCurryBlock blkElem, parentSeqCtx, blkElem.val.args.length
  seqCtx = new SeqContext parentSeqCtx
  wordCtx = new WordContext b, parentWordCtx

  for e in b.seq
    if e.val instanceof ast.Word
      v = wordEval e, seqCtx, wordCtx
      if v instanceof ast.Block
        for ve in v.seq
          seqCtx.retBlk.seq.push ve
      else
        seqCtx.retBlk.seq.push new ast.Elem null, v
    else
      seqCtx.retBlk.seq.push e
  seqCtx.retBlk


interp.eval = (blk) ->
  blockEval blk, null, null















