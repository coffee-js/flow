parser = exports
pc = require "../pc"
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


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
      pc.neg(pc.seq pc.tok('>>'), endToken),
      pc.neg(name)), endToken),
    (n) -> new ast.NodeWord n[0].reduce (t,s)->t.concat(s)

  elem = null
  _elem = pc.lazy ->elem

  args = pc.map pc.seq(pc.rep1(word), pc.tok('>>'), pc.space()),
    (n) -> n[0]
  seq = pc.rep1 _elem

  block = pc.map pc.seq(pc.tok('['), pc.space(), pc.optional(args), pc.optional(seq), pc.tok(']'), endToken),
    (n) ->
      args = if n[2]==true then [] else n[2]
      seq = if n[3]==true then [] else n[3]
      new ast.NodeBlock args, seq
  value = pc.choice block, number, string, word

  elem = pc.map pc.seq(pc.optional(name), value),
    (n, pos) -> new ast.NodeElem (if n[0]==true then null else n[0]), n[1], pos

  { int10, number, string, colon, negws, nameChar, name, word, elem, seq, block, value }


for k, v of combinator
  parser[k] = v


parser.parse = (src) ->
  p = pc.map pc.seq(parser.seq, pc.end()), (n) -> n[0]
  r = p pc.ps src.txt
  if r.match == null
    [line, col] = src.lineCol r.state.lastFailPos
    log "parse error: pos:#{line}:#{col}"
  r




