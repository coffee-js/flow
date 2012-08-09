pc = require "../pc"
parser = require "./parser"
ast = require "./ast"

pp = (s) -> console.log JSON.stringify s, null, '  '


describe "Fn Parser", ->

  describe "combinator number", ->

    it "match number", ->
      p = parser.number
      (expect (p pc.ps "123").match.val).toEqual 123
      (expect (p pc.ps " ").match).toEqual null
      (expect (p pc.ps "-123").match.val).toEqual -123
      (expect (p pc.ps "abc").match).toEqual null
      (expect (p pc.ps "000").match.val).toEqual 0
      (expect (p pc.ps "000").state.pos).toEqual 3


  describe "combinator string", ->

    it "match string", ->
      p = parser.string
      (expect (p pc.ps "\" hello ! \" abc").match.val).toEqual " hello ! "
      (expect (p pc.ps "abc").match).toEqual null
      (expect (p pc.ps "123").match).toEqual null
      (expect (p pc.ps "\"\"").match.val).toEqual ""
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
        }
        {
          name: null
          val:
            val: 435
        }
        {
          name: null
          val:
            name: "dfg"
        }
      ]
      (expect (p pc.ps "sd: serdgd 465 [ 564 ]").match).toEqual [
        {
          name: "sd"
          val:
            name: "serdgd"
        }
        {
          name: null
          val:
            val: 465
        }
        {
          name: null
          val:
            args: []
            seq: [
              {
                name: null
                val:
                  val: 564
              }
            ]
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
                  val:
                    val: 45
                }
                {
                  name: null
                  val:
                    name: "[]"
                }
              ]
          }
          {
            name: null
            val:
              name: "-"
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
                  val:
                    val: 45
                }
                {
                  name: null
                  val:
                    name: "[]"
                }
              ]
          }
          {
            name: null
            val:
              name: "-"
          }
          {
            name: null
            val:
              name: "aa"
          }
        ]
      }




