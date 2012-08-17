interp = exports
ast = require "./ast"


log = (s) -> console.log s


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


getArgs = (elem, n, seqCtx, blk) ->
  l = seqCtx.retBlk.seq.length
  if l < n
    if seqCtx.parent == null
      err "no enough args in context:#{seqCtx}", elem.pos, blk.src
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


blockWrap = (a) ->
  new ast.Block [], [], (a.map (v) -> new ast.Elem v)


bw = ->
  new BuildinWord arguments...


buildinWords = {
  ";":    bw 0, (seqCtx, wordCtx) -> seqCtx.retBlk.seq.length = 0; blockWrap []

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
      err "cond is not a boolean: #{cond.val}", cond.pos, b.src
    if !(whenTrue.val instanceof ast.Block)
      err "whenTrue is not a block: #{whenTrue.val}", whenTrue.pos, b.src
    if !(whenFals.val instanceof ast.Block)
      err "whenFals is not a block: #{whenFals.val}", whenFals.pos, b.src

    if cond.val
      blockEval whenTrue, seqCtx, wordCtx
    else
      blockEval whenFals, seqCtx, wordCtx

  'do':   bw 1, (seqCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", e.pos, b.src
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
    @retBlk = new ast.Block [], [], []


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
  else if wordElem.val.name.match /^js\//i
    args = []
    for e in seqCtx.retBlk.seq
      v = e.val
      if typeof(v) == 'string'
        args.push "\"" + v + "\""
      else
        args.push v
    a = args.join ","
    jsCode = wordElem.val.name.slice(3) + "(" + a + ")"
    v = eval jsCode
    if v == undefined
      blockWrap []
    else
      v
  else
    err "word:\"#{wordElem.val.name}\" not defined", wordElem.pos, wordCtx.block.src


readElemInBlock = (wordElem, seqCtx, wordCtx) ->
  [b] = getArgs wordElem, 1, seqCtx, wordCtx
  name = wordElem.val.name.slice 0,-2
  if name.match /\d+/
    n = parseInt(name)
    w = b.val.seq[n-1]
    if w == undefined
      err "no elem nth:#{n} in block #{b}", wordElem.pos, wordCtx.block.src
  else
    w = b.val.words[name]
    if w == undefined
      err "no word named:#{name} in block #{b}", wordElem.pos, wordCtx.block.src
  blockWrap [w.val]


writeElemInBlock = (wordElem, seqCtx, wordCtx) ->
  [b, w] = getArgs wordElem, 2, seqCtx, wordCtx
  name = wordElem.val.name.slice 2
  if name.match /\d+/
    n = parseInt(name)
    b.val.seq[n-1] = w
  else
    b.val.words[name] = w
  blockWrap [b.val]


wordEval1 = (wordElem, seqCtx, wordCtx) ->
  wordName = wordElem.val.name
  if      wordName.match /.+>>$/
    readElemInBlock wordElem, seqCtx, wordCtx
  else if wordName.match /^>>.+/
    writeElemInBlock wordElem, seqCtx, wordCtx
  else
    wordEval wordElem, seqCtx, wordCtx


seqCurryBlock = (blkElem, seqCtx, n) ->
  if n < 1
    return blkElem.val
  blk = blkElem.val
  if n > blk.args.length
    err "n > blk.args.length", blkElem.pos, blk.src
  args = getArgs blkElem, n, seqCtx
  argWords = {}

  for i in [0..n-1]
    a = blk.args[i]
    v = args[n-i-1]
    argWords[a.name] = v
  blk.curry argWords


blockEval = (blkElem, parentSeqCtx, parentWordCtx) ->
  b = seqCurryBlock blkElem, parentSeqCtx, blkElem.val.args.length
  seqCtx = new SeqContext parentSeqCtx
  wordCtx = new WordContext b, parentWordCtx

  for e in b.seq
    if e.val instanceof ast.Word
      v = wordEval1 e, seqCtx, wordCtx
      if v instanceof ast.Block
        for ve in v.seq
          seqCtx.retBlk.seq.push ve
      else
        seqCtx.retBlk.seq.push new ast.Elem v
    else
      seqCtx.retBlk.seq.push e
  seqCtx.retBlk


interp.eval = (blk) ->
  blockEval blk, null, null















