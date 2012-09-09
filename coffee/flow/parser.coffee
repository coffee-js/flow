parser = exports
pc = require "../pc"
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if pos != null && src != null
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


combinator = do ->
  int10 = pc.map pc.rep1(pc.range '0','9'), (n) -> n.reduce (t,s) -> t.concat(s)

  number = pc.map pc.seq(pc.optional(pc.tok '-'), int10),
    (n) -> parseInt(if n[0]=='-' then n[0].concat(n[1]) else n[1])

  string = pc.map pc.seq(pc.tok('"'), pc.rep0(pc.choice pc.tok('\\"'), pc.neg(pc.tok('"'))), pc.tok('"')),
    (n) ->
      if n[1].length > 0
        n[1].reduce (t,s) -> t.concat(s)
      else ""

  colon = pc.ch ":"
  sep = pc.ch "."
  wordChar = pc.and pc.neg(pc.space()), pc.neg(sep), pc.neg(pc.ch "[]{}")
  nameChar = pc.and wordChar, pc.neg(pc.seq colon, pc.space())

  name = pc.map pc.seq(pc.rep1(nameChar), colon, pc.space()),
    (n) -> n[0].reduce (t,s) -> t.concat(s)

  endWord = pc.choice(pc.space(), pc.ch("[]{}"), pc.end())
  wordName = pc.map pc.and(
      pc.rep1(wordChar),
      pc.neg(pc.seq pc.tok(">>"), endWord),
      pc.neg(name)),
    (n) -> n.reduce (t,s) -> t.concat(s)

  wordRefine = pc.map pc.rep1(pc.seq(sep, wordName)),
    (n) -> n.map (nn) -> nn.reduce (s,w) -> w

  wordOpt = pc.choice pc.tok("#!"), pc.ch("'#:")
  word = pc.map pc.seq(pc.optional(wordOpt), pc.choice(
      pc.seq(wordName, pc.optional(wordRefine)),
      wordRefine
    )), (n, pos, src) ->
      a = n[1]
      if a[1] == true
        entry = a[0]
        refines = []
      else if a[1] instanceof Array
        entry = a[0]
        refines = a[1]
      else
        entry = null
        refines = a
      opt = if n[0]==true then null else n[0]
      new ast.Word entry, refines, opt, new ast.SrcInfo(pos, src)

  elem = null
  _elem = pc.lazy -> elem

  args = pc.map pc.seq(pc.rep1(pc.ws(wordName)), pc.ws(pc.tok('>>'))),
    (n) -> n[0]

  namedElem = pc.map pc.seq(name, _elem),
    (n, pos, src) ->
      name = n[0]
      e = n[1]
      if e instanceof ast.Block
        e.srcInfo.name = name
      {name, elem:e, srcInfo:(new ast.SrcInfo pos, src)}

  wordMap = pc.rep1 pc.ws(namedElem)
  seq = pc.rep1 pc.ws(_elem)
  body = pc.map pc.seq(pc.optional(wordMap), pc.optional(seq)),
    (n) ->
      wordSeq = if n[0]==true then [] else n[0]
      seq     = if n[1]==true then [] else n[1]
      {wordSeq, seq}

  block = pc.map pc.seq(pc.optional(pc.ws(args)), pc.ws(body)),
    (n, pos, src) ->
      args = if n[0]==true then [] else n[0]
      wordSeq = n[1].wordSeq
      seq     = n[1].seq
      [args, wordSeq, seq, new ast.SrcInfo(pos, src)]

  evalBlock = pc.map pc.seq(pc.tok('['), pc.ws(block), pc.ws(pc.tok(']'))),
    (n, pos) ->
      args = n[1]
      srcInfo = args.pop()
      srcInfo.pos = pos
      args = args.concat ["EVAL", srcInfo]
      new ast.Block args...

  valBlock = pc.map pc.seq(pc.tok('{'), pc.ws(block), pc.ws(pc.tok('}'))),
    (n, pos) ->
      args = n[1]
      srcInfo = args.pop()
      srcInfo.pos = pos
      args = args.concat ["VAL", srcInfo]
      new ast.Block args...

  elem = pc.choice evalBlock, valBlock, number, string, word

  { int10, number, string, colon, wordChar, nameChar, name, wordName, wordRefine, word, elem, wordMap, seq, body, block, evalBlock, valBlock }


for k, v of combinator
  parser[k] = v


parser.parse = (src) ->
  p = pc.map pc.seq(parser.body, pc.end()), (n) -> n[0]
  r = p pc.ps src
  if r.match == null
    err "syntex error", r.state.lastFailPos, src
  
  new ast.Block [], r.match.wordSeq, r.match.seq, "EVAL", new ast.SrcInfo(0, src)


















