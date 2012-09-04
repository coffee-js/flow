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
  constructor: (@argCount, @fn) ->

  eval: (retSeq, srcInfo=null) ->
    args = retSeq.slice -@argCount
    if args.length < @argCount
      err "no enough args in seq:#{retSeq}", srcInfo
    retSeq.length = retSeq.length-@argCount
    args = [retSeq].concat args
    @fn args...


bw = ->
  new BuildinWord arguments...

ct = (e, ta...) ->
  for t in ta
    if typeof(e.val) == t
      pass = true
  if !pass
    ts = ta.join " or "
    err "expect a #{ts}, got:[#{e.val}:#{typeof(e.val)}]", e.srcInfo

ct2 = (a, b, t) ->
  ct a, t; ct b, t

ck = (e, ka...) ->
  ct e, "object"
  for k in ka
    if e.val instanceof k
      pass = true
  if !pass
    ks = ka.join " or "
    err "expect a #{ks}: #{e.val}", e.srcInfo


buildinWords = {
  "+":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val+b.val
  "-":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val-b.val
  "*":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val*b.val
  "/":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val/b.val
  "%":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val%b.val
  "neg":  bw 1, (retSeq, a)    -> ct  a,    "number"; -a.val
  "abs":  bw 1, (retSeq, a)    -> ct  a,    "number"; Math.abs a.val

  "=":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val==b.val
  "<":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val<b.val
  ">":    bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val>b.val
  "<=":   bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val<=b.val
  ">=":   bw 2, (retSeq, a, b) -> ct2 a, b, "number"; a.val>=b.val

  "not":  bw 1, (retSeq, a)    -> ct  a,    "boolean"; !a.val
  "and":  bw 2, (retSeq, a, b) -> ct2 a, b, "boolean"; a.val&&b.val
  "or":   bw 2, (retSeq, a, b) -> ct2 a, b, "boolean"; a.val||b.val

  "if":   bw 3, (retSeq, cond, whenTrue, whenFals) ->
    ct cond, 'boolean'
    ck whenTrue, Closure
    ck whenFals, Closure

    if cond.val
      seqApplyEval whenTrue.val, retSeq
    else
      seqApplyEval whenFals.val, retSeq
    undefined

  "eval": bw 1, (retSeq, elem) ->
    ck elem, Closure
    c = elem.val
    seqApplyEval c, retSeq
    undefined

  "get":  bw 2, (retSeq, cElem, nameElem) ->
    ck cElem, Closure
    ct nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    [found, elem] = c.getElem name
    if found
      elem.val
    else
      err "no elem named:#{name} in block #{c}", nameElem.srcInfo

  "set":  bw 3, (retSeq, cElem, elem, nameElem) ->
    ck cElem, Closure
    ct nameElem, "number", "string"

    c = cElem.val
    name = nameElem.val
    c.setElem name, elem

  "len":  bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.len()

  "arg-word-count": bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.argWordCount

  "word-count": bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.wordCount()

  "count": bw 1, (retSeq, cElem) ->
    ck cElem, Closure
    c = cElem.val
    c.count()

  "slice": bw 3, (retSeq, cElem, start, end) ->
    ck cElem, Closure
    ct start, "number"; ct end, "number"

    c = cElem.val
    c.slice start.val, end.val

  "join": bw 2, (retSeq, a, b) ->
    ck a, Closure; ck b, Closure
    a.val.join b.val

  "splice": bw 4, (retSeq, cElem, iElem, delCountElem, addElemsCElem) ->
    ck cElem, Closure
    ct iElem, "number"; ct delCountElem, "number"

    ck addElemsCElem, Closure
    c = cElem.val
    c.splice iElem.val, delCountElem.val, addElemsCElem.val.seq()

  "curry": bw 2, (retSeq, cElem, nElem) ->
    ck cElem, Closure
    ct nElem, "number"

    c = cElem.val
    n = nElem.val
    if n > c.args.length
      argN = c.args.length
      seqN = n - c.args.length
    else
      argN = n
    argWords = seqCurryArgWords c, retSeq, argN, cElem.srcInfo
    r = c.apply argWords
    if seqN != undefined
      unshifts = retSeq.slice -seqN
      retSeq.length = retSeq.length-seqN
      r = r.splice 1, 0, unshifts
    r

  "wcurry": bw 2, (retSeq, wElem, cElem) ->
    ck wElem, Closure
    ck cElem, Closure

    w = wElem.val
    c = cElem.val
    w.wordEnvInit()
    argWords = w.words
    c.apply argWords
}


class Context
  constructor: (@parent) ->
    if @parent == null
      @retSeq = []
    else
      @retSeq = @parent.retSeq


sepWordNameProc = (name) ->
  opt = {}
  switch name[0]
    when "'"
      opt.notEval = true
      name = name.slice 1
  [name, opt]


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
  [name, opt] = sepWordNameProc name
  v = wordInEnv(name, wordEnv)
  if v == undefined
    v = buildinWords[name]
  else if opt.notEval
    v = v.valDup()
  v


seqCurryArgWords = (c, retSeq, n, srcInfo=null) ->
  if n < 1
    return {}
  if n > c.args.length
    err "closure:#{c} args count:#{c.args.length} < #{n}", srcInfo
  argWords = {}
  if retSeq.length < n
    err "no enough elems in seq, seq.len:#{retSeq.length} n:#{n}", srcInfo
  args = retSeq.slice -n
  for i in [0..n-1]
    a = c.args[i]
    w = args[i]
    argWords[a.name] = w
  retSeq.length = retSeq.length-n
  argWords


seqApply = (c, retSeq, srcInfo=null) ->
  if c.args.length > 0
    argWords = seqCurryArgWords c, retSeq, c.args.length, srcInfo
    c.apply argWords
  else
    c


seqApplyEval = (c, retSeq, srcInfo=null) ->
  (seqApply c, retSeq, srcInfo).eval retSeq


seqEval = (val, retSeq, wordEnv, srcInfo=null) ->
  if      val instanceof Closure && val.elemType == "EVAL"
    seqApplyEval val, retSeq, srcInfo
  else if val instanceof BuildinWord
    v = val.eval retSeq, srcInfo
    if v != undefined
      seqEval v, retSeq, wordEnv, srcInfo
  else
    retSeq.push new ast.Elem val, srcInfo


class Word
  constructor: (@name, @wordEnv) ->


class Closure
  constructor: (@block, @preWordEnv, argWords=null) ->
    @elemType = @block.elemType
    @words = {}
    @argWords = {}
    @argWordCount = 0
    if argWords
      @args = []
      for a in @block.args
        if argWords[a.name] == undefined
          @args.push a
        else
          @words[a.name] = @argWords[a.name] = argWords[a.name]
          @argWordCount += 1
    else
      @args = @block.args

  valDup: ->
    switch @elemType
      when "EVAL"
        c = new Closure @block, @preWordEnv, @argWords
        c.elemType = "VAL"
        c
      when "VAL"
        @
      else
        err "fatal error: #{@} @elemType:#{@elemType}"

  wordEnvInit: ->
    if @wordEnv != undefined
      return
    @wordEnv = [@words].concat @preWordEnv
    for name of @block.words
      e = @block.words[name]
      if e == null
        continue
      if      e.val instanceof ast.Word
        v = new Word e.val.name, @wordEnv
      else if e.val instanceof ast.Block
        v = new Closure e.val, @wordEnv
      else
        v = e.val
      e = new ast.Elem v, name, e.srcInfo
      @words[name] = e

  elemEval: (e) ->
    @wordEnvInit()
    if      e.val instanceof ast.Word
      v = wordVal e.val.name, @wordEnv
      if v == undefined
        err "word:#{e.val.name} not defined", e.srcInfo
    else if e.val instanceof ast.Block
      args = []
      for a in @block.args
        if @argWords[a.name] == undefined
          args.push a
      b = e.val.addArgs args
      v = new Closure b, @wordEnv
    else
      v = e.val
    v

  eval: (retSeq) ->
    for e in @block.seq
      seqEval @elemEval(e), retSeq, @wordEnv, e.srcInfo

  apply: (argWords) ->
    aw = {}
    for a in @block.args
      if @argWords[a.name] != undefined
        aw[a.name] = @argWords[a.name]
      if argWords[a.name] != undefined
        aw[a.name] = argWords[a.name]
    new Closure @block, @preWordEnv, aw

  seq: ->
    if @_seq != undefined
      return @_seq
    @_seq = []
    for e in @block.seq
      @_seq.push new ast.Elem @elemEval(e), e.srcInfo
    @_seq

  getElem: (name) ->
    [name, opt] = sepWordNameProc name
    [found, e] = @block.getElem name
    if found
      if e != null
        e = new ast.Elem @elemEval(e), e.srcInfo
      else if @argWords[name] != undefined
        e = @argWords[name]
      else
        found = false
    if found && e.val instanceof Closure && opt.notEval
      e.val = e.val.valDup()
    [found, e]

  setElem: (name, elem) ->
    if @block.argWords[name] != undefined
      aw = {}
      for a in @block.args
        if @argWords[a.name] != undefined
          aw[a.name] = @argWords[a.name]
      aw[name] = elem
      new Closure @block, @preWordEnv, aw
    else
      b = @block.setElem name, elem
      new Closure b, @preWordEnv, @argWords

  len: -> @block.len()
  wordCount: -> @block.wordCount - @block.args.length + @argWordCount
  count: -> @len() + @wordCount()

  slice: (p1, p2) ->
    b = @block.slice p1, p2
    new Closure b, @preWordEnv, @argWords

  join: (other) ->
    b = @block.join other.block
    aw = {}
    for name of @argWords
      aw[name] = @argWords[name]
    for name of other.argWords
      aw[name] = other.argWords[name]
    new Closure b, @preWordEnv, aw

  splice: (i, delCount, addElems) ->
    b = @block.splice i, delCount, addElems
    new Closure b, @preWordEnv, @argWords



interp.eval = (blockElem) ->
  retSeq = []
  c = new Closure blockElem.val, []
  c.eval retSeq
  retSeq













