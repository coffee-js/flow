parser = exports
pc = require "../pc"
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


err = (s, pos=null, src=null) ->
  if (pos != null) && (src != null)
    [line, col] = src.lineCol pos
    throw "#{src.path}:#{line}:#{col} #{s}"
  else
    throw s


combinator = do ->
  endToken = pc.choice pc.space(), pc.end()

  int10 = pc.map pc.rep1(pc.range '0','9'), (n)->n.reduce (t,s)->t.concat(s)
  number = pc.map pc.seq(pc.optional(pc.tok '-'), int10, endToken),
    (n) -> parseInt(if n[0]=='-' then n[0].concat(n[1]) else n[1])

  string = pc.map pc.seq(pc.tok('"'), pc.rep0(pc.choice pc.tok('\\"'), pc.neg(pc.tok('"'))), pc.tok('"'), endToken),
    (n) -> if n[1].length > 0 then n[1].reduce (t,s)->t.concat(s) else ""

  colon = pc.tok ':'
  negws = pc.neg pc.space()
  nameChar = pc.and negws, pc.neg(pc.seq colon, pc.space())

  name = pc.map pc.seq(pc.rep1(nameChar), colon, endToken),
    (n) -> n[0].reduce (t,s)->t.concat(s)

  word = pc.map pc.seq( pc.and(
      pc.rep1(pc.neg pc.space()),
      pc.neg(pc.seq pc.ch('[]'), endToken),
      pc.neg(pc.seq pc.ch('{}'), endToken),
      pc.neg(pc.seq pc.tok('>>'), endToken),
      pc.neg(name)), endToken),
    (n) -> new ast.Word n[0].reduce (t,s)->t.concat(s)

  elem = null
  _elem = pc.lazy ->elem

  args = pc.map pc.seq(pc.rep1(word), pc.tok('>>'), pc.space()),
    (n) -> n[0]

  namedElem = pc.map pc.seq(name, _elem),
    (n, pos) ->
      name = n[0]
      e = n[1]
      e.name = name
      e.srcInfo.pos = pos
      {name, elem:e}

  wordMap = pc.rep1(namedElem)
  seq = pc.rep1 _elem
  body = pc.map pc.seq(pc.optional(wordMap), pc.optional(seq)),
    (n) ->
      wordSeq = if n[0]==true then [] else n[0]
      seq     = if n[1]==true then [] else n[1]
      {wordSeq, seq}

  block = pc.map pc.seq(pc.optional(args), body),
    (n, pos, src) ->
      args = if n[0]==true then [] else n[0]
      wordSeq = n[1].wordSeq
      seq     = n[1].seq
      [args, wordSeq, seq, new ast.SrcInfo(pos, src)]

  evalBlock = pc.map pc.seq(pc.tok('['), pc.space(), block, pc.tok(']'), endToken),
    (n, pos) ->
      args = n[2]
      srcInfo = args.pop()
      srcInfo.pos = pos
      args = args.concat ["EVAL", srcInfo]
      new ast.Block args...

  valBlock = pc.map pc.seq(pc.tok('{'), pc.space(), block, pc.tok('}'), endToken),
    (n, pos) ->
      args = n[2]
      srcInfo = args.pop()
      srcInfo.pos = pos
      args = args.concat ["VAL", srcInfo]
      new ast.Block args...

  elem = pc.map pc.choice(evalBlock, valBlock, number, string, word),
    (n, pos) -> new ast.Elem n, null, new ast.SrcInfo(pos)

  { int10, number, string, colon, negws, nameChar, name, word, elem, wordMap, seq, body, block, evalBlock, valBlock }


for k, v of combinator
  parser[k] = v


parser.parse = (src) ->
  p = pc.map pc.seq(parser.body, pc.end()), (n) -> n[0]
  r = p pc.ps src
  if r.match == null
    err "syntex error", r.state.lastFailPos, src
  
  b = new ast.Block [], r.match.wordSeq, r.match.seq, "EVAL", new ast.SrcInfo(0, src)
  e = new ast.Elem b, null, new ast.SrcInfo(0)
  e



