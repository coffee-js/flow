interp = exports
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, srcInfo=null) ->
  if srcInfo != null
    src = srcInfo.src
    [line, col] = src.lineCol srcInfo.pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s



class BuildinWord
  constructor: (@numArgs, @fn) ->

  eval: (retSeq, srcInfo=null) ->
    args = retSeq.slice -@numArgs
    if args.length < @numArgs
      err "no enough args in seq:#{retSeq}", srcInfo
    retSeq.length = retSeq.length-@numArgs
    args = [retSeq].concat args
    @fn args...

bw = ->
  new BuildinWord arguments...


buildinWords = {
  "+":    bw 2, (retSeq, a, b) -> a.val+b.val
  "-":    bw 2, (retSeq, a, b) -> a.val-b.val
  "*":    bw 2, (retSeq, a, b) -> a.val*b.val
  "/":    bw 2, (retSeq, a, b) -> a.val/b.val

  "=":    bw 2, (retSeq, a, b) -> a.val==b.val
  "<":    bw 2, (retSeq, a, b) -> a.val<b.val
  ">":    bw 2, (retSeq, a, b) -> a.val>b.val
  "<=":   bw 2, (retSeq, a, b) -> a.val<=b.val
  ">=":   bw 2, (retSeq, a, b) -> a.val>=b.val

  "not":  bw 1, (retSeq, a)    -> !a.val
  "and":  bw 2, (retSeq, a, b) -> a.val&&b.val
  "or":   bw 2, (retSeq, a, b) -> a.val||b.val

  "if":   bw 3, (retSeq, cond, whenTrue, whenFals) ->
    if typeof cond.val != 'boolean'
      err "expect a boolean: #{cond.val}", cond.srcInfo
    if !(whenTrue.val instanceof Closure)
      err "expect a block: #{whenTrue.val}", whenTrue.srcInfo
    if !(whenFals.val instanceof Closure)
      err "expect a block: #{whenFals.val}", whenFals.srcInfo

    if cond.val
      seqCurryEval whenTrue.val, retSeq
    else
      seqCurryEval whenFals.val, retSeq
    undefined

  "eval":   bw 1, (retSeq, elem) ->
    c = elem.val
    if !(c instanceof Closure)
      err "expect a block: #{c}", elem.srcInfo
    seqCurryEval c, retSeq
    undefined
}



wordInEnv = (name, wordEnv) ->
  for words in wordEnv
    e = words[name]
    if e != undefined
      if e.val instanceof Word
        return wordInEnv e.val.name, e.val.wordEnv
      else
        return e.val
  undefined


wordVal = (name, wordEnv) ->
  e = wordInEnv(name, wordEnv)
  if e == undefined
    e = buildinWords[name]
  e


seqCurryArgWords = (c, retSeq, n, srcInfo=null) ->
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c} max args num is #{c.args.length}", srcInfo
  argWords = {}
  args = retSeq.slice -n
  for i in [0..n-1]
    a = c.args[i]
    w = args[i]
    argWords[a.name] = w
  retSeq.length = retSeq.length-n
  argWords


seqCurryEval = (c, retSeq, srcInfo=null) ->
  if c.args.length > 0
    argWords = seqCurryArgWords c, retSeq, c.args.length, srcInfo
    (c.curry argWords).eval retSeq
  else
    c.eval retSeq


seqEval = (val, retSeq, wordEnv, srcInfo=null) ->
  if val instanceof Closure && val.elemType == "EVAL"
    seqCurryEval val, retSeq, srcInfo
  else if val instanceof BuildinWord
    v = val.eval retSeq, srcInfo
    if v != undefined
      seqEval v, retSeq, wordEnv
  else
    retSeq.push new ast.Elem val, srcInfo


class Word
  constructor: (@name, @wordEnv) ->


class Closure
  constructor: (@block, @preWordEnv, argWords=null) ->
    @elemType = @block.elemType
    @words = {}
    if argWords
      @args = []
      for a in @block.args
        if argWords[a.name] == undefined
          @args.push a
        else
          @words[a.name] = argWords[a.name]
    else
      @args = @block.args

  eval: (retSeq) ->
    wordEnv = [@words].concat @preWordEnv
    for name of @block.words
      e = @block.words[name]
      if      e.val instanceof ast.Word
        v = new Word e.val.name, wordEnv
      else if e.val instanceof ast.Block
        v = new Closure e.val, wordEnv
      else
        v = e.val
      e = new ast.Elem v, name, e.srcInfo
      @words[name] = e

    for e in @block.seq
      if      e.val instanceof ast.Word
        v = wordVal e.val.name, wordEnv
        if v == undefined
          err "word:#{e.val.name} not defined", e.srcInfo
      else if e.val instanceof ast.Block
        v = new Closure e.val, wordEnv
      else
        v = e.val
      seqEval v, retSeq, wordEnv, e.srcInfo

  curry: (argWords) ->
    new Closure @block, @preWordEnv, argWords


interp.eval = (blockElem) ->
  retSeq = []
  c = new Closure blockElem.val, []
  c.eval retSeq
  retSeq













