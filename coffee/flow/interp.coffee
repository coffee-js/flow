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
      seqCurryEval whenTrue.val, retSeq
    else
      seqCurryEval whenFals.val, retSeq
    undefined

  "eval":   bw 1, (retSeq, wordEnv, block, elem) ->
    c = elem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", elem.srcInfo.pos, block.srcInfo.src
    seqCurryEval c, retSeq
    undefined

  "get":  bw 2, (retSeq, wordEnv, block, cElem, nameElem) ->
    c = cElem.val
    name = nameElem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src
    
    [found, elem] = c.getElem name
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{c}", nameElem.srcInfo.pos, block.srcInfo.src

  # "set":  bw 3, (retSeq, wordEnv, block, cElem, elem, nameElem) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src
  #   name = nameElem.val
  #   c.block.setElem name, elem

  # "len":  bw 1, (retSeq, wordEnv, block, cElem) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{cElem.val}", cElem.srcInfo.pos, block.srcInfo.src
  #   c.block.len()

  # "num-words": bw 1, (retSeq, wordEnv, block, cElem) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src
  #   c.block.numWords

  # "num-elems": bw 1, (retSeq, wordEnv, block, cElem) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src
  #   c.block.numElems()

  # "slice":  bw 3, (retSeq, wordEnv, block, cElem, start, end) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src
  #   c.block.slice start.val, end.val

  # "join":   bw 2, (retSeq, wordEnv, block, a, c) ->
  #   if !(a.val instanceof Closure)
  #     err "expect a block: #{a.val}", a.srcInfo.pos, block.srcInfo.src
  #   if !(c.val instanceof Closure)
  #     err "expect a block: #{c.val}", c.srcInfo.pos, block.srcInfo.src
  #   a.val.block.join c.val.block

  # "splice":  bw 4, (retSeq, wordEnv, block, cElem, i, numDel, addElemsBElem) ->
  #   c = cElem.val
  #   if !(c instanceof Closure)
  #     err "expect a block: #{c}", cElem.srcInfo.pos, block.srcInfo.src

  #   aeb = addElemsBElem.val.block
  #   addElems = aeb.seq.slice 0
  #   c.block.splice i, numDel, addElems
}


blockWordEnv = (block, argWords, preWordEnv) ->
  words = {}
  wordEnv = [words].concat preWordEnv
  args = []

  for a in block.args
    if argWords[a.name] != undefined
      words[a.name] = argWords[a.name]
    else
      args.push a

  for name of block.words
    w = block.words[name]
    if w.val instanceof ast.Block
      c = new Closure w.val, wordEnv, {}
      words[name] = new ast.Elem c, w.name, w.srcInfo
    else
      words[name] = w
  [wordEnv, args, words]


wordInEnv = (word, wordEnv) ->
  name = word.name
  for i in [0...wordEnv.length]
    words = wordEnv[i]
    w = words[name]
    if w != undefined
      if w.val instanceof ast.Word
        return wordInEnv w.val, wordEnv.slice(i)
      else
        return w.val
  undefined


wordEval = (wordElem, wordEnv) ->
  name = wordElem.val.name
  w = wordInEnv wordElem.val, wordEnv
  if w == undefined
    w = buildinWords[name]
  w


seqCurryArgWords = (c, retSeq, n) ->
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c} max args num is #{c.args.length}", c.block.srcInfo.pos, c.block.srcInfo.src
  argWords = {}
  args = retSeq.slice -n
  for i in [0..n-1]
    a = c.args[i]
    w = args[i]
    argWords[a.name] = w
  retSeq.length = retSeq.length-n
  argWords


seqCurryEval = (c, retSeq) ->
  argWords = seqCurryArgWords c, retSeq, c.args.length
  (c.curry argWords).eval retSeq


valEval = (val, e, retSeq, wordEnv, block) ->
  if val instanceof Closure && val.block.elemType == "EVAL"
    seqCurryEval val, retSeq
  else if val instanceof BuildinWord
    v = val.eval e, retSeq, wordEnv, block
    if v != undefined
      valEval v, e, retSeq, wordEnv, block
  else
    if val instanceof ast.Block
      val = new Closure val, wordEnv, {}
    retSeq.push new ast.Elem val, null, e.srcInfo


class Closure
  constructor: (@block, preWordEnv, argWords) ->
    [@wordEnv, @args, @words] = blockWordEnv @block, argWords, preWordEnv

  curry: (argWords) ->
    if argWords == {}
      @
    else
      new Closure @block, @wordEnv, argWords

  seq: ->
    if @_seq == undefined
      @_seq = []
      for e in @block.seq
        if      e.val instanceof ast.Word
          val = wordEval e, @wordEnv
          if val == undefined
            err "word:#{e.val.name} not defined", e.srcInfo.pos, @block.srcInfo.src
        else if e.val instanceof ast.Block
          val = new Closure e.val, @wordEnv, {}
        else
          val = e.val
        @_seq.push new ast.Elem val, null, e.srcInfo
    @_seq

  eval: (retSeq) ->
    for e in @seq()
      valEval e.val, e, retSeq, @wordEnv, @block

  getElem: (name) ->
    found = false
    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name
    if n != undefined
      if n<0 then n = @seq().length+n+1
      elem = @seq()[n-1]
      if elem != undefined
        found = true
      else
        elem = null
    else
      elem = @words[name]
      if elem != undefined
        found = true
      else
        elem = null
    [found, elem]


interp.eval = (blockElem) ->
  retSeq = []
  c = new Closure blockElem.val, [], {}
  c.eval retSeq
  retSeq













