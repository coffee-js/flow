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
}


wordInEnv = (name, wordEnv) ->
  for words in wordEnv
    w = words[name]
    if w != undefined
      if w.val instanceof Array
        switch w.val[0]
          when "word"
            return wordInEnv w.val[1], w.val[2]
          when "block"
            return new Closure v.slice(1)...
          else
            return w.val
      else
        return w.val
  undefined

wordVal = (name, wordEnv) ->
    w = wordInEnv(name, wordEnv)
    if w == undefined
      w = buildinWords[name]
    w

elemVal = (e) ->
  v = e.val
  while v instanceof Array
    switch v[0]
      when "word"
        v1 = wordVal v[1], v[2]
        if v1 == undefined
          return v
        else
          v = v1
      when "block"
        v = new Closure v.slice(1)...
      else
        v
  v

preElemVal = (e, wordEnv, args) ->
  if      e.val instanceof ast.Block
    v = ["block", e.val, wordEnv, args]
  else if e.val instanceof ast.Word
    v = ["word", e.val.name, wordEnv]
  else
    v = e.val

closureFromBlock = (b, preWordEnv, preArgs=[]) ->
  args = preArgs.concat b.args
  words = {}

  wordEnv = [words].concat preWordEnv

  for name of b.words
    e = b.words[name]
    v = preElemVal e, wordEnv, args
    w = new ast.Elem v, e.srcInfo
    words[name] = w

  for name of words
    e = words[name]
    w = new ast.Elem elemVal(e), e.srcInfo
    words[name] = w

  seq = b.seq.map (e) ->
    v = preElemVal e, wordEnv, args
    e = new ast.Elem v, e.srcInfo
    new ast.Elem elemVal(e), e.srcInfo
  new Closure args, words, seq, b.elemType



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

valEval = (val, retSeq, wordEnv, srcInfo=null) ->
  if val instanceof Closure && val.elemType == "EVAL"
    seqCurryEval val, retSeq, srcInfo
  else if val instanceof BuildinWord
    v = val.eval retSeq, srcInfo
    if v != undefined
      valEval v, retSeq, wordEnv
  else
    retSeq.push new ast.Elem val, srcInfo




class Closure
  constructor: (@args, @words, @seq, @elemType) ->

  eval: (retSeq) ->
    for e in @seq
      if e.val instanceof Array
        err "word:#{e.val[1]} not defined", e.srcInfo
      valEval e.val, retSeq, e.wordEnv, e.srcInfo

  curry: (argWords) ->
    if argWords == {}
      @
    else
      args = []
      words = {}
      seq = []
      new Closure args, words, seq, @elemType



interp.eval = (blockElem) ->
  retSeq = []
  c = closureFromBlock blockElem.val, []
  c.eval retSeq
  retSeq













