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


  describe "combinator negws", ->

    it "match negws", ->
      p = parser.negws
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


  describe "combinator word", ->

    it "match word", ->
      p = parser.word
      (expect (parse p, " ").match).toEqual null
      (expect (parse p, "abc").match.name).toEqual "abc"
      (expect (parse p, "abc: ").match).toEqual null
      (expect (parse p, "abc:").match.name).toEqual "abc:"
      (expect (parse p, "[").match).toEqual null
      (expect (parse p, "]").match).toEqual null
      (expect (parse p, "[abc").match.name).toEqual "[abc"
      (expect (parse p, "[abc]").match.name).toEqual "[abc]"
      (expect (parse p, "{([])").match.name).toEqual "{([])"


  describe "combinator seq", ->

    it "match seq", ->
      p = parser.seq
      (expect (parse p, "x: sdf 435 dfg").match).toEqual [
        {
          name: "x"
          val:
            name: "sdf"
          pos: 0
        }
        {
          name: null
          val: 435
          pos: 7
        }
        {
          name: null
          val:
            name: "dfg"
          pos: 11
        }
      ]
      (expect (parse p, "sd: serdgd 465 [ 564 ]").match[2].val.seq).toEqual [
        {
          name: null
          val: 564
          pos: 17
        }
      ]


  describe "combinator block", ->

    it "match block", ->
      p = parser.block

      (expect (parse p, "[]").match).toEqual null

      a = (parse p, "[ [ sd: 45 [] ] - ]").match
      (expect a.seq[0].val.seq).toEqual [
        {
          name: "sd"
          val: 45
          pos: 4
        }
        {
          name: null
          val:
            name: "[]"
          pos: 11
        }
      ]
      a = (parse p, "[ aa bb >> [ cc >> sd: 45 [] ] - aa ]").match
      (expect a.args).toEqual [
        {
          name: "aa"
        }
        {
          name: "bb"
        }
      ]
      (expect a.seq[0].val.seq).toEqual [
        {
          name: "sd"
          val: 45
          pos: 19
        }
        {
          name: null
          val:
            name: "[]"
          pos: 26
        }
      ]


  describe "parse", ->

    it "print error info", ->

      src = new pc.Source "1 2 [", null
      (expect (->parser.parse src)).toThrow "parse error: pos:1:5"

      src = new pc.Source "a: [ n >> n: 1 2 + ] ; a", null
      (expect (->parser.parse src)).toThrow "1:11 redefined: n"




