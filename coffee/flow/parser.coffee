parser = exports
pc = require "../pc"
ast = require "./ast"


combinator = do ->
  ws = (p) ->
    pc.map pc.seq(p, pc.choice pc.space(), pc.end()), (n)->n[0]

  int10 = pc.map pc.rep1(pc.range '0','9'), (n)->n.reduce (t,s)->t.concat(s)
  number = pc.map pc.seq(pc.optional(pc.tok '-'), int10, pc.space()),
    (n) -> new ast.NodeValue parseInt(if n[0]=='-' then n[0].concat(n[1]) else n[1])

  string = pc.map pc.seq(pc.tok('"'), pc.rep0(pc.choice pc.tok('\\"'), pc.neg(pc.tok('"'))), pc.tok('"'), pc.space()),
    (n) -> new ast.NodeValue if n[1].length > 0 then n[1].reduce (t,s)->t.concat(s) else ""

  colon = pc.tok ':'
  negws = pc.neg pc.space()
  nameChar = pc.and negws, pc.neg(pc.seq colon, pc.space())
  name = pc.map pc.seq(pc.rep1(nameChar), colon, pc.space()),
    (n) -> n[0].reduce (t,s)->t.concat(s)

  word = pc.map pc.seq(pc.and(pc.rep1(pc.neg pc.space()), pc.neg(ws(pc.ch '[]')), pc.neg(name)), pc.space()),
    (n) -> new ast.NodeWord n[0].reduce (t,s)->t.concat(s)

  elem = null
  _elem = pc.lazy ->elem

  seq = pc.rep1 _elem
  block = pc.map pc.seq(pc.tok('['), pc.space(), pc.optional(seq), pc.tok(']'), pc.space()),
    (n) -> new ast.NodeBlock if n[2]==true then [] else n[2]
  value = pc.choice block, number, string, word

  elem = pc.map pc.seq(pc.optional(name), value),
    (n) -> new ast.NodeElem (if n[0]==true then null else n[0]), n[1]

  { int10, number, string, colon, negws, nameChar, name, word, elem, seq, block, value }


for k, v of combinator
  parser[k] = v


parser.parse = (src) ->
  parser.seq pc.ps src






