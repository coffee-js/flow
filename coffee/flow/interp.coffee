interp = exports
ast = require "./ast"


log = (s) -> console.log s


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


getArgs = (elem, n, retCtx, blk) ->
  l = retCtx.retBlk.seq.length
  if l < n
    if retCtx.parent == null
      err "no enough args in context:#{retCtx}", elem.pos, blk.src
    else
      args0 = getArgs elem, n-l, retCtx.parent
  p = if l-n < 0 then 0 else l-n
  args = retCtx.retBlk.seq.slice p
  if args0 != undefined
    args = args0.concat args
  retCtx.retBlk.seq.length = p
  args


class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (elem, retCtx, wordCtx) ->
    args = getArgs elem, @numArgs, retCtx, wordCtx
    a = [retCtx, wordCtx].concat args
    @fn a...


blockWrap = (seq, wordSeq=[]) ->
  new ast.Block [], wordSeq, seq


bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (retCtx, wordCtx, a, b) -> a.val+b.val
  "-":    bw 2, (retCtx, wordCtx, a, b) -> a.val-b.val
  "*":    bw 2, (retCtx, wordCtx, a, b) -> a.val*b.val
  "/":    bw 2, (retCtx, wordCtx, a, b) -> a.val/b.val

  "=":    bw 2, (retCtx, wordCtx, a, b) -> a.val==b.val
  "<":    bw 2, (retCtx, wordCtx, a, b) -> a.val<b.val
  ">":    bw 2, (retCtx, wordCtx, a, b) -> a.val>b.val
  "<=":   bw 2, (retCtx, wordCtx, a, b) -> a.val<=b.val
  ">=":   bw 2, (retCtx, wordCtx, a, b) -> a.val>=b.val

  "not":  bw 1, (retCtx, wordCtx, a)    -> !a.val
  "and":  bw 2, (retCtx, wordCtx, a, b) -> a.val&&b.val
  "or":   bw 2, (retCtx, wordCtx, a, b) -> a.val||b.val

  "if":   bw 3, (retCtx, wordCtx, cond, whenTrue, whenFals) ->
    b = wordCtx.block
    if typeof(cond.val) != 'boolean'
      err "cond is not a boolean: #{cond.val}", cond.pos, b.src
    if !(whenTrue.val instanceof ast.Block)
      err "whenTrue is not a block: #{whenTrue.val}", whenTrue.pos, b.src
    if !(whenFals.val instanceof ast.Block)
      err "whenFals is not a block: #{whenFals.val}", whenFals.pos, b.src

    if cond.val
      blockEval whenTrue, retCtx, wordCtx
    else
      blockEval whenFals, retCtx, wordCtx

  "do":   bw 1, (retCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    blockEval b, retCtx, wordCtx

  ";":    bw 0, (retCtx, wordCtx) ->
    retCtx.retBlk.seq.length = 0
    blockWrap []

  "wrap": bw 0, (retCtx, wordCtx) ->
    r = retCtx.retBlk.clone()
    retCtx.retBlk.seq.length = 0
    blockWrap [new ast.Elem r]

  "subseq": bw 3, (retCtx, wordCtx, b, start, end) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    seq = b.val.seq.slice start.val-1, end.val
    r = blockWrap seq, b.val.wordSeq()
    blockWrap [new ast.Elem r]

  "num-elems": bw 1, (retCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    b.val.numWords + b.val.seq.length

  "num-words": bw 1, (retCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    b.val.numWords

  "seq-len": bw 1, (retCtx, wordCtx, b) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    b.val.seq.length

  "join": bw 2, (retCtx, wordCtx, a, b) ->
    if !(a.val instanceof ast.Block)
      err "#{a.val} is not a block", a.val.pos, a.val.src
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    seq = a.val.seq.concat b.val.seq
    wordSeq = a.val.wordSeq().concat b.val.wordSeq()
    r = blockWrap seq, wordSeq
    blockWrap [new ast.Elem r]

  "rm-elems": bw 2, (retCtx, wordCtx, b, names) ->
    if !(b.val instanceof ast.Block)
      err "#{b.val} is not a block", b.val.pos, b.val.src
    if !(names.val instanceof ast.Block)
      err "#{names.val} is not a block", names.val.pos, names.val.src

    r = b.val.clone()
    for w in names.val.seq
      if w.val.name == undefined
        n = parseInt w.val
        r.seq[n-1] = undefined
        r.seq = r.seq.filter (x)-> x!=undefined
      else
        delete r.words[w.val.name]
        r.numWords -= 1
    blockWrap [new ast.Elem r]
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


class RetContext
  constructor: (wordSeq, @parent=null) ->
    @retBlk = new ast.Block [], wordSeq, []


wordEval = (wordElem, retCtx, wordCtx) ->
  evalBlock = true
  name = wordElem.val.name
  if name.match /^'/
    name = name.slice 1
    evalBlock = false
  [word, wordCtx1] = wordCtx.getWord name
  if word instanceof BuildinWord
    word.eval wordElem, retCtx, wordCtx
  else if word != null && word.val != null
    if      word.val instanceof ast.Block
      if evalBlock
        blockEval word, retCtx, wordCtx1
      else
        blockWrap [new ast.Elem word.val, null, word.pos]
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
    err "word:\"#{name}\" not defined", wordElem.pos, wordCtx.block.src


readElemInBlock = (wordElem, retCtx, wordCtx) ->
  [b] = getArgs wordElem, 1, retCtx, wordCtx
  name = wordElem.val.name.slice 0,-2
  if name.match /\d+$/
    n = parseInt name
    if n<0 then n = b.val.seq.length+n+1
    w = b.val.seq[n-1]
    if w == undefined
      err "no elem nth:#{n} in block #{b}", wordElem.pos, wordCtx.block.src
  else
    w = b.val.words[name]
    if w == undefined
      err "no word named:#{name} in block #{b}", wordElem.pos, wordCtx.block.src
  blockWrap [w]


writeElemInBlock = (wordElem, retCtx, wordCtx) ->
  [b, w] = getArgs wordElem, 2, retCtx, wordCtx
  b = new ast.Elem b.val.clone(), null, b.pos
  name = wordElem.val.name.slice 2
  if name.match /\d+$/
    n = parseInt(name)
    if n<0 then n = b.val.seq.length+n+1
    b.val.seq[n-1] = w
  else
    b.val.words[name] = w
  blockWrap [b]


wordEval1 = (wordElem, retCtx, wordCtx) ->
  wordName = wordElem.val.name
  if      wordName.match /.+>>$/
    readElemInBlock wordElem, retCtx, wordCtx
  else if wordName.match /^>>.+/
    writeElemInBlock wordElem, retCtx, wordCtx
  else
    wordEval wordElem, retCtx, wordCtx


seqCurryBlock = (blkElem, retCtx, n) ->
  if n < 1
    return blkElem.val
  blk = blkElem.val
  if n > blk.args.length
    err "n > blk.args.length", blkElem.pos, blk.src
  args = getArgs blkElem, n, retCtx
  argWords = {}

  for i in [0..n-1]
    a = blk.args[i]
    v = args[i]
    argWords[a.name] = v
  blk.curry argWords


blockEval = (blkElem, parentSeqCtx, parentWordCtx) ->
  b = seqCurryBlock blkElem, parentSeqCtx, blkElem.val.args.length
  retCtx = new RetContext b.wordSeq(), parentSeqCtx
  wordCtx = new WordContext b, parentWordCtx

  for e in b.seq
    if e.val instanceof ast.Word
      v = wordEval1 e, retCtx, wordCtx
      if v instanceof ast.Block
        for ve in v.seq
          retCtx.retBlk.seq.push ve
      else
        retCtx.retBlk.seq.push new ast.Elem v
    else
      retCtx.retBlk.seq.push e
  retCtx.retBlk


interp.eval = (blk) ->
  blockEval blk, null, null















