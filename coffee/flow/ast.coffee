ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


class ast.SrcInfo
  constructor: (@pos=null, @src=null) ->


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->
    @val = null


class ast.Elem extends ast.Node
  constructor: (@val, @name=null, srcInfo=null) ->
    if srcInfo == null
      @srcInfo = new ast.SrcInfo null, null
    else
      @srcInfo = srcInfo

  clone: ->
    if @val instanceof ast.Block
      v = @val.clone()
    else if @val instanceof ast.Word
      v = new ast.Word @val.name
    else
      v = @val
    new ast.Elem v, @name, @srcInfo


class ast.Block extends ast.Node
  constructor: (@args, wordSeq, @seq, srcInfo=null) ->
    if srcInfo == null
      @srcInfo = new ast.SrcInfo null, null
    else
      @srcInfo = srcInfo

    argWords = {}
    for a in args
      argWords[a.name] = null

    @words = {}
    @numWords = 0
    for e in wordSeq
      name = e.name
      if (@words[name] != undefined) or (argWords[name] != undefined)
        err "redefined word:\"#{name}\"", e.elem.srcInfo.pos, @srcInfo.src
      w = @words[name] = e.elem
      @numWords += 1
      if (w.val instanceof ast.Block) && (w.val.parent == null)
        w.val.parent = @

    for e in @seq
      if (e.val instanceof ast.Block) && (e.val.parent == null)
        e.val.parent = @

    @parent = null
    @elemType = "EVAL"


  updateElemBlockParent: (origs) ->
    for o in origs
      for name of @words
        v = @words[name].val
        if (v instanceof ast.Block) && (v.parent == o)
          v.parent = @
      for e in @seq
        v = e.val
        if (v instanceof ast.Block) && (v.parent == o)
          v.parent = @


  curry: (argWords) ->
    args = []

    wordSeq = @wordSeqClone @wordSeq()
    seq = @seq.map (e) -> e.clone()

    for a in @args
      if argWords[a.name] != undefined
        name = a.name
        elem = argWords[a.name].clone()
        wordSeq.push {name, elem}
      else
        args.push a

    b = new ast.Block args, wordSeq, seq, @srcInfo
    b.updateElemBlockParent [@]
    b.parent = @parent
    b.elemType = @elemType
    b


  getWord: (name) ->
    elem = @words[name]
    if elem != undefined
      if (elem != null) && (elem.val instanceof ast.Word)
        elem = @getWord elem.val.name
    else if @parent != null
      elem = @parent.getWord name
    else
      elem = null
    elem


  wordSeq: ->
    wordSeq = []
    for name of @words
      elem = @words[name]
      wordSeq.push {name, elem}
    wordSeq


  wordSeqClone: (wordSeq) ->
    wordSeq.map (e) ->
      name = e.name
      elem = e.elem.clone()
      {name, elem}


  clone: ->
    wordSeq = @wordSeqClone @wordSeq()
    seq = @seq.map (e) -> e.clone()
    b = new ast.Block @args.slice(0), wordSeq, seq, @srcInfo
    b.updateElemBlockParent [@]
    b.parent = @parent
    b.elemType = @elemType
    b


  join: (other, parent) ->
    args = @args.concat other.args
    wordSeq = @wordSeqClone @wordSeq().concat other.wordSeq()
    seq = (@seq.concat other.seq).map (e) -> e.clone()
    b = new ast.Block args, wordSeq, seq
    b.updateElemBlockParent [@, other]
    if parent != null
      b.parent = parent
    b.elemType = "VAL"
    b


  unshift: (elem) ->
    wordSeq = @wordSeqClone @wordSeq()
    seq = @seq.map (e) -> e.clone()
    seq.unshift elem
    b = new ast.Block @args, wordSeq, seq
    b.updateElemBlockParent [@]
    b.parent = @parent
    b.elemType = @elemType
    b


  slice: (p1, p2) ->
    if p1 < 0 then p1 = @seq.length + p1 + 1
    if p2 < 0 then p2 = @seq.length + p2 + 2
    wordSeq = @wordSeqClone @wordSeq()
    seq = (@seq.slice p1-1, p2).map (e) -> e.clone()
    b = new ast.Block @args, wordSeq, seq
    b.updateElemBlockParent [@]
    b.parent = @parent
    b.elemType = @elemType
    b


  numElems: ->
    @numWords + @seq.length


  getElem: (name) ->
    found = false

    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name

    if n != undefined
      if n<0 then n = @seq.length+n+1
      elem = @seq[n-1]
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


  setElem: (name, elem) ->
    blk = @clone()

    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name

    if n != undefined
      if n<0 then n = blk.seq.length+n+1
      blk.seq[n-1] = elem.clone()
    else
      blk.words[name] = elem.clone()
    blk





