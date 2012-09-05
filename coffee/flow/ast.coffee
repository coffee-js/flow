ast = exports
pc = require "../pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, srcInfo=null) ->
  if srcInfo != null
    throw "#{srcInfo.toStr()} #{s}"
  else
    throw s


class ast.SrcInfo
  constructor: (@pos=null, @src=null, @name=null) ->

  toStr: ->
    [line, col] = @src.lineCol @pos
    s = "#{@src.path}:#{line}:#{col}"
    if @name != null
      s += ":<#{@name}>"
    s


class ast.Node


class ast.Word extends ast.Node
  constructor: (@name) ->

  toStr: ->
    @name


class ast.Elem extends ast.Node
  constructor: (@val, @srcInfo=null) ->

  toStr: ->
    switch typeof(@val)
      when "number"
        @val
      when "string"
        "\"#{@val.replace('"','\"')}\""
      when "object"
        @val.toStr()
      else
        err "elem val type:#{typeof(@val)}", @srcInfo


class ast.Block extends ast.Node
  constructor: (@args, wordSeq, @seq, @elemType, @srcInfo=null) ->
    @wordCount = 0
    @argWords = {}
    @words = {}
    for a in args
      @words[a.name] = @argWords[a.name] = null
      @wordCount += 1

    for e in wordSeq
      name = e.name
      if @words[name] != undefined
        err "redefined word:\"#{name}\"", e.elem.srcInfo
      @words[name] = e.elem
      @wordCount += 1

  wordSeq: ->
    wordSeq = []
    for name of @words
      if @argWords[name] != undefined
        continue
      elem = @words[name]
      wordSeq.push {name, elem}
    wordSeq

  addArgs: (aa) ->
    if aa.length == 0
      return @
    args = []
    for a in aa
      if @argWords[a.name] == undefined
        args.push a
    for a in @args
      args.push a
    new ast.Block args, @wordSeq(), @seq.slice(0), @elemType, @srcInfo

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
    seq = @seq.slice 0
    wordIdx = {}
    wordSeq = []
    i = 0
    for k of @words
      wordIdx[k] = i
      wordSeq.push {name:k, elem:words[k]}
      i += 1

    if typeof name == "number"
      n = name
    else if name.match /\d+$/
      n = parseInt name
    if n != undefined
      if n<0 then n = seq.length+n+1
      seq[n-1] = elem
    else
      if wordIdx[name] != undefined
        wordSeq[ wordIdx[name] ].elem = elem
      else
        wordSeq.push {name, elem}
    new ast.Block @args, wordSeq, seq, @elemType, @srcInfo

  len: ->
    @seq.length

  nonArgWordCount: ->
    @wordCount - @args.length

  count: ->
    @wordCount + @len()

  slice: (p1, p2) ->
    if p1 < 0 then p1 = @seq.length + p1 + 1
    if p2 < 0 then p2 = @seq.length + p2 + 1
    seq = @seq.slice p1-1, p2
    new ast.Block @args, @wordSeq(), seq, @elemType, @srcInfo

  join: (other) ->
    args = []
    argWordIdx = {}
    i = 0
    for a in @args
      argWordIdx[a.name] = i
      args.push a
      i += 1
    for a in other.args
      if argWordIdx[a.name] != undefined
        args[ argWordIdx[a.name] ] = a
      else
        args.push a
    
    wordSeq = []
    myWordSeq = @wordSeq()
    wordIdx = {}
    i = 0
    for w in myWordSeq
      wordIdx[w.name] = i
      wordSeq.push w
      i += 1
    otherWordSeq = other.wordSeq()
    for w in otherWordSeq
      if wordIdx[w.name] != undefined
        wordSeq[ wordIdx[w.name] ] = w
      else
        wordSeq.push w

    seq = @seq.concat other.seq
    new ast.Block args, wordSeq, seq, "VAL", null

  splice: (i, numDel, addElems) ->
    seq = @seq.slice 0
    seq.splice i-1, numDel, addElems...
    new ast.Block @args, @wordSeq(), seq, @elemType, @srcInfo

  filterArgWords: ->
    new ast.Block @args, [], [], @elemType, @srcInfo

  filterWords: ->
    new ast.Block @args, @wordSeq(), [], @elemType, @srcInfo

  filterNonArgWords: ->
    new ast.Block [], @wordSeq(), [], @elemType, @srcInfo

  filterSeq: ->
    new ast.Block [], [], @seq, @elemType, @srcInfo

  toStr: ->
    s = ""
    if @args.length > 0
      for a in @args
        s += "#{a.name} "
      s += ">> "
    for name of @words
      if @words[name] != null
        s += "#{name}: #{@words[name].toStr()} "
    for e in @seq
      s += "#{e.toStr()} "
    switch @elemType
      when "EVAL"
        "[ #{s}]"
      when "VAL"
        "{ #{s}}"
      else
        err "@elemType error"
















