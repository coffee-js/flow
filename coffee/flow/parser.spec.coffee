pc = require "../pc"
parser = require "./parser"
ast = require "./ast"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


describe "Flow Parser", ->

  describe "combinator number", ->

    it "match number", ->
      p = parser.number
      (expect (p pc.ps "123").match).toEqual 123
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "-123").match).toEqual -123
      (expect (p pc.ps "abc").match).toEqual null
      (expect (p pc.ps "000").match).toEqual 0
      (expect (p pc.ps "000").state.pos).toEqual 3


  describe "combinator string", ->

    it "match string", ->
      p = parser.string
      (expect (p pc.ps "\" hello ! \" abc").match).toEqual " hello ! "
      (expect (p pc.ps "abc").match).toEqual null
      (expect (p pc.ps "123").match).toEqual null
      (expect (p pc.ps "\"\"").match).toEqual ""
      (expect (p pc.ps "\"abc").match).toEqual null


  describe "combinator colon", ->

    it "match colon", ->
      p = parser.colon
      (expect (p pc.ps ":a").match).toEqual ":"
      (expect (p pc.ps "aa").match).toEqual null


  describe "combinator negws", ->

    it "match negws", ->
      p = parser.negws
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "aa").match).toEqual "a"


  describe "combinator nameChar", ->

    it "match nameChar", ->
      p = parser.nameChar
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "aa").match).toEqual "a"
      (expect (p pc.ps ":").match).toEqual ":"
      (expect (p pc.ps ": ").match).toEqual null


  describe "combinator name", ->

    it "match name", ->
      p = parser.name
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "aa: ").match).toEqual "aa"
      (expect (p pc.ps "aa:").match).toEqual null
      (expect (p pc.ps "aa").match).toEqual null


  describe "combinator word", ->

    it "match word", ->
      p = parser.word
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "abc").match.name).toEqual "abc"
      (expect (p pc.ps "abc: ").match).toEqual null
      (expect (p pc.ps "abc:").match.name).toEqual "abc:"
      (expect (p pc.ps "[").match).toEqual null
      (expect (p pc.ps "]").match).toEqual null
      (expect (p pc.ps "[abc").match.name).toEqual "[abc"
      (expect (p pc.ps "[abc]").match.name).toEqual "[abc]"
      (expect (p pc.ps "{([])").match.name).toEqual "{([])"


  describe "combinator seq", ->

    it "match seq", ->
      p = parser.seq
      (expect (p pc.ps "x: sdf 435 dfg").match).toEqual [
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
      (expect (p pc.ps "sd: serdgd 465 [ 564 ]").match).toEqual [
        {
          name: "sd"
          val:
            name: "serdgd"
          pos: 0
        }
        {
          name: null
          val: 465
          pos: 11
        }
        {
          name: null
          val:
            args: []
            seq: [
              {
                name: null
                val: 564
                pos: 17
              }
            ]
          pos: 15
        }
      ]


  describe "combinator block", ->

    it "match block", ->
      p = parser.block
      (expect (p pc.ps "[]").match).toEqual null
      (expect (p pc.ps "[ [ sd: 45 [] ] - ]").match).toEqual {
        args: []
        seq: [
          {
            name: null
            val:
              args: []
              seq: [
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
            pos: 2
          }
          {
            name: null
            val:
              name: "-"
            pos: 16
          }
        ]
      }
      (expect (p pc.ps "[ aa bb >> [ cc >> sd: 45 [] ] - aa ]").match).toEqual {
        args: [
          {
            name: "aa"
          }
          {
            name: "bb"
          }
        ]
        seq: [
          {
            name: null
            val:
              args: [
                {
                  name: "cc"
                }
              ]
              seq: [
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
            pos: 11
          }
          {
            name: null
            val:
              name: "-"
            pos: 31
          }
          {
            name: null
            val:
              name: "aa"
            pos: 33
          }
        ]
      }

  describe "parse", ->

    it "print error info", ->

      src = new ast.Source "1 2 [", null
      (expect (->parser.parse src)).toThrow "parse error: pos:1:5"







