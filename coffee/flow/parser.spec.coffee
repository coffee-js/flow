pc = require "../pc"
parser = require "./parser"
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


parse = (parser, s, pos) ->
  src = new pc.Source s, null
  parser pc.ps src, pos


describe "Flow Parser", ->

  describe "combinator number", ->

    it "match number", ->
      p = parser.number
      (expect (parse p, "123").match).toEqual 123
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "-123").match).toEqual -123
      (expect (parse p, "abc").match).toEqual null
      (expect (parse p, "000").match).toEqual 0
      (expect (parse p, "000").state.pos).toEqual 3


  describe "combinator string", ->

    it "match string", ->
      p = parser.string
      (expect (parse p, "\" hello ! \" abc").match).toEqual " hello ! "
      (expect (parse p, "abc").match).toEqual null
      (expect (parse p, "123").match).toEqual null
      (expect (parse p, "\"\"").match).toEqual ""
      (expect (parse p, "\"abc").match).toEqual null


  describe "combinator colon", ->

    it "match colon", ->
      p = parser.colon
      (expect (parse p, ":a").match).toEqual ":"
      (expect (parse p, "aa").match).toEqual null


  describe "combinator wordChar", ->

    it "match wordChar", ->
      p = parser.wordChar
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "aa").match).toEqual "a"


  describe "combinator nameChar", ->

    it "match nameChar", ->
      p = parser.nameChar
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "aa").match).toEqual "a"
      (expect (parse p, ":").match).toEqual ":"
      (expect (parse p, ": ").match).toEqual null


  describe "combinator name", ->

    it "match name", ->
      p = parser.name
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "aa: ").match).toEqual "aa"
      (expect (parse p, "aa:").match).toEqual null
      (expect (parse p, "aa").match).toEqual null


  describe "combinator wordName", ->

    it "match wordName", ->
      p = parser.wordName
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "abc").match).toEqual "abc"
      (expect (parse p, "abc: ").match).toEqual null
      (expect (parse p, "abc:").match).toEqual "abc:"
      (expect (parse p, "[").match).toEqual null
      (expect (parse p, "]").match).toEqual null
      (expect (parse p, "[abc").match).toEqual null
      (expect (parse p, "[abc]").match).toEqual null
      (expect (parse p, "{([])").match).toEqual null
      (expect (parse p, ">>").match).toEqual null


  describe "combinator wordRefine", ->

    it "match wordRefine", ->
      p = parser.wordRefine
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, ".abc").match).toEqual ["abc"]
      (expect (parse p, ".a.b.c").match).toEqual ["a","b","c"]


  describe "combinator word", ->

    it "match word", ->
      p = parser.word
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "abc").match.entry).toEqual "abc"
      (expect (parse p, "a.b.c").match.entry).toEqual "a"
      (expect (parse p, "a.b.c").match.refines).toEqual ["b","c"]
      (expect (parse p, ".b.c").match.entry).toEqual null
      (expect (parse p, ".b.c").match.refines).toEqual ["b","c"]
      (expect (parse p, "'.b.c").match.refines).toEqual ["b","c"]
      (expect (parse p, "'.b.c").match.opt).toEqual "'"


  describe "combinator seq", ->

    it "match seq", ->
      p = parser.seq
      t = (parse p, "sdf 435 dfg").match
      (expect t[0].name).toEqual "sdf"
      (expect t[0].srcInfo.pos).toEqual 0
      (expect t[1]).toEqual 435
      t = (parse p, "serdgd 465 [564]").match[2].seq[0]
      (expect t).toEqual 564


  describe "combinator block", ->

    it "match block", ->
      p = parser.evalBlock

      a = (parse p, "[[sd: 45 aa] -]").match
      (expect a.seq[0].words["sd"]).toEqual 45
      (expect a.seq[0].seq[0].name).toEqual "aa"

      a = (parse p, "[aa bb >> [cc >> sd: 45 aa] - aa]").match
      (expect a.args[1]).toEqual "bb"
      (expect a.seq[0].words["sd"]).toEqual 45
      (expect a.seq[0].seq[0].name).toEqual "aa"


  describe "parse", ->

    it "print error info", ->

      src = new pc.Source "1 2 [", null
      (expect (->parser.parse src)).toThrow "null:1:4 syntex error"

      src = new pc.Source "a: [n >> n: 1 2 +] a", null
      (expect (->parser.parse src)).toThrow "null:1:10 redefined word:\"n\""




