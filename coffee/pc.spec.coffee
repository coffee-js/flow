pc = require "./pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


parse = (parser, s, pos) ->
  src = new pc.Source s, null
  parser pc.ps src, pos


describe "Parser Combinator", ->

  describe "tok", ->

    it "match string", ->
      p = pc.tok("abc")
      (expect (parse p, "abc").match).toEqual "abc"
      (expect (parse p, "abcdefg ").match).toEqual "abc"
      (expect (parse p, " abcdefg ").match).toEqual null

    it "save last fail pos", ->
      p = pc.tok("abc")
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "123456 abcdefg ", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "123456 abcdefg ", 7).state.lastFailPos).toEqual null


  describe "ch", ->

    it "match 1 charter", ->
      p = pc.ch("x")
      (expect (parse p, "x").match).toEqual "x"
      (expect (parse p, "xyz").match).toEqual "x" 
      (expect (parse p, "yzx").match).toEqual null

      p = pc.ch("0")
      (expect (parse p, "0").match).toEqual "0"

    it "match 1 of charter arguments", ->
      p = pc.ch("xyz")
      (expect (parse p, "x").match).toEqual "x"
      (expect (parse p, "xyz").match).toEqual "x"
      (expect (parse p, "yzx").match).toEqual "y"
      (expect (parse p, "z").match).toEqual "z"
      (expect (parse p, "a").match).toEqual null

    it "save last fail pos", ->
      p = pc.ch("xyz")
      (expect (parse p, "12345x", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345y", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345z", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "12345y", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345 y", 5).state.lastFailPos).toEqual 5


  describe "range", ->

    it "match charter in range", ->
      p = pc.range("a", "z")
      (expect (parse p, "x3").match).toEqual "x"
      (expect (parse p, "a1").match).toEqual "a"
      (expect (parse p, "z2").match).toEqual "z"
      (expect (parse p, "A3").match).toEqual null
      (expect (parse p, "Z4").match).toEqual null
      (expect (parse p, "X3").match).toEqual null
      (expect (parse p, "16").match).toEqual null

    it "save last fail pos", ->
      p = pc.range("a", "z")
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "123456 xy ", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "123456fz ", 7).state.lastFailPos).toEqual null


  describe "regexp", ->

    it "match regexp", ->
      p = pc.regexp /abc$/
      (expect (parse p, "abc").match).toEqual "abc"
      (expect (parse p, "abcd").match).toEqual null


  describe "space", ->

    it "match space", ->
      p = pc.space()
      (expect (parse p, " abc").match).toEqual " "
      (expect (parse p, "\tabc").match).toEqual "\t"
      (expect (parse p, "\rabc").match).toEqual "\r"
      (expect (parse p, "\n\tabc").match).toEqual "\n\t"
      (expect (parse p, "abc").match).toEqual null
      (expect (parse p, "").match).toEqual null

    it "save last fail pos", ->
      p = pc.space()
      (expect (parse p, "12345 ", 5).state.lastFailPos).toEqual null
      (expect (parse p, "1234567", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "123456  ", 7).state.lastFailPos).toEqual null


  describe "number", ->

    it "match number", ->
      p = pc.number()
      (expect (parse p, "1").match).toEqual "1"
      (expect (parse p, "1.1").match).toEqual "1.1"
      (expect (parse p, "0.05").match).toEqual "0.05"
      #(expect (parse p, "0xff").match).toEqual "0xff"


  describe "ws", ->

    it "match something with space before it", ->
      p = pc.ws(pc.tok "abc")
      (expect (parse p, " \t\nabc").match).toEqual "abc"
      (expect (parse p, "abc").match).toEqual "abc"

    it "save last fail pos", ->
      p = pc.ws(pc.seq pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345 abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "1234567\t\nabc", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "123456  \n\n\n\n\nabc", 7).state.lastFailPos).toEqual null
      (expect (parse p, "12345 abd", 5).state.lastFailPos).toEqual 8


  describe "choice", ->

    it "match 1 of given patterns", ->
      p = pc.choice pc.tok("abc"), pc.ch("xyz"), pc.range("1","3")
      (expect (parse p, "y").match).toEqual "y"
      (expect (parse p, "abc").match).toEqual "abc"
      (expect (parse p, "2").match).toEqual "2"
      (expect (parse p, "4").match).toEqual null
      (expect (parse p, " abc").match).toEqual null

    it "save last fail pos", ->
      p = pc.choice \
        pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c")),
        pc.seq(pc.ch("x"), pc.ch("y"), pc.ch("z"))
      (expect (parse p, "12345abcd", 5).state.lastFailPos).toEqual null
      (expect (parse p, "1234567\t\nabc", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "12345acb", 5).state.lastFailPos).toEqual 6
      (expect (parse p, "12345xyx", 5).state.lastFailPos).toEqual 7


  describe "seq", ->

    it "match patterns sequence", ->
      p = pc.seq pc.tok("abc"), pc.space(), pc.ch("xyz"), pc.range("0","3")
      (expect (parse p, "abc y0").match).toEqual ["abc"," ","y","0"]
      (expect (parse p, "abc y").match).toEqual null
      (expect (parse p, "0abc y1").match).toEqual null

    it "save last fail pos", ->
      p = pc.seq pc.tok("abc"), pc.space(), pc.ch("xyz"), pc.range("1","3")
      (expect (parse p, "12345abc y1", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abc a1", 5).state.lastFailPos).toEqual 9
      (expect (parse p, "12345abc y0", 5).state.lastFailPos).toEqual 10
      (expect (parse p, "12345abc y2", 5).state.lastFailPos).toEqual null


  describe "optional", ->

    it "match optional pattern", ->
      p = pc.optional pc.tok("abc")
      (expect (parse p, "abc").match).toEqual "abc"
      (expect (parse p, "abcdefg ").match).toEqual "abc"
      (expect (parse p, " abcdefg ").match).toEqual true

      p = pc.seq p, pc.space(), pc.ch("xyz"), pc.range("1","3")
      (expect (parse p, "abc y1").match).toEqual ["abc"," ","y","1"]
      (expect (parse p, " y1").match).toEqual [true," ","y","1"]
      (expect (parse p, "x y1").match).toEqual null

    it "save last fail pos", ->
      p = pc.optional pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abd", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345xyz", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345", 4).state.lastFailPos).toEqual null


  describe "rep0", ->

    it "match pattern 0 more times", ->
      p = pc.rep0 pc.tok("abc")
      (expect (parse p, "abcdef").match).toEqual ["abc"]
      (expect (parse p, "abcabcdef").match).toEqual ["abc", "abc"]
      (expect (parse p, "adef").match).toEqual []

    it "save last fail pos", ->
      p = pc.rep0 pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345abcabc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abcabc", 6).state.lastFailPos).toEqual null
      (expect (parse p, "12345abcabc", 5).state.pos).toEqual 11
      (expect (parse p, "12345abcabd", 5).state.pos).toEqual 8


  describe "rep1", ->

    it "match pattern 1 more times", ->
      p = pc.rep1 pc.tok("abc")
      (expect (parse p, "abcdef").match).toEqual ["abc"]
      (expect (parse p, "abcabcdef").match).toEqual ["abc", "abc"]
      (expect (parse p, "adef").match).toEqual null

    it "save last fail pos", ->
      p = pc.rep1 pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345abcabc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abcabc", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "12345abcabcbbc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abdabc", 5).state.lastFailPos).toEqual 7


  describe "neg", ->

    it "match 1 char with negative pattern", ->
      p = pc.neg pc.tok("abc")
      (expect (parse p, "abc").match).toEqual null
      (expect (parse p, "abcd").match).toEqual null
      (expect (parse p, " abc").match).toEqual " "
      (expect (parse p, "1abc").match).toEqual "1"

    it "save last fail pos", ->
      p = pc.neg pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual 5
      (expect (parse p, "12345", 5).state.lastFailPos).toEqual 5
      (expect (parse p, "123456", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345abd", 5).state.lastFailPos).toEqual null
      (expect (parse p, "1234", 5).state.lastFailPos).toEqual 5
      (expect (parse p, "123", 5).state.lastFailPos).toEqual 5


	describe "map", ->

		it "map matched with a function", ->
			p = pc.map pc.tok("abc"), (m)-> m+"def"
			(expect (parse p, "abc").match).toEqual "abcdef"
			(expect (parse p, "123").match).toEqual null

		it "save last fail pos", ->
			p = pc.map pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c")), (m)-> m+"def"
			(expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
			(expect (parse p, "12345abd", 5).state.lastFailPos).toEqual 7


  describe "end", ->

    it "match no string", ->
      p = pc.end()
      (expect (parse p, "abc").match).toEqual null
      (expect (parse p, "").match).toEqual true

    it "save last fail pos", ->
      p = pc.end()
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual 5
      (expect (parse p, "12345", 5).state.lastFailPos).toEqual null
      (expect (parse p, "1234", 5).state.lastFailPos).toEqual 5


  describe "lazy", ->

    it "for break cyclic depend define", ->
      x = null
      p = pc.lazy -> x
      x = pc.tok("123")
      (expect (parse p, "123").match).toEqual "123"
      (expect (parse p, "abc").match).toEqual null

    it "save last fail pos", ->
      x = null
      p = pc.lazy -> x
      x = pc.tok("abc")
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "123456 abcdefg ", 6).state.lastFailPos).toEqual 6
      (expect (parse p, "123456 abcdefg ", 7).state.lastFailPos).toEqual null


  describe "and", ->

    it "match all pattern", ->
      p = pc.and pc.range("a","z"), pc.ch("xyz")
      (expect (parse p, "z").match).toEqual "z"
      (expect (parse p, "a").match).toEqual null
      (expect (parse p, "X").match).toEqual null

    it "save last fail pos", ->
      p = pc.and pc.tok("abc"), pc.range("a","z"), pc.seq(pc.ch("a"), pc.ch("b"), pc.ch("c"))
      (expect (parse p, "12345abc", 5).state.lastFailPos).toEqual null
      (expect (parse p, "12345X", 5).state.lastFailPos).toEqual 5
      (expect (parse p, "12345a", 5).state.lastFailPos).toEqual 5




