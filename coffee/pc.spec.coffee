pc = require "./pc"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


describe "Parser Combinator", ->

	describe "tok", ->

		it "match string", ->
			p = pc.tok("abc")
			(expect (p pc.ps "abc").match).toEqual "abc"
			(expect (p pc.ps "abcdefg ").match).toEqual "abc"
			(expect (p pc.ps " abcdefg ").match).toEqual null

		it "save last fail pos", ->
			p = pc.tok("abc")
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "123456 abcdefg ", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "123456 abcdefg ", 7).state.lastFailPos).toEqual null


	describe "ch", ->

		it "match 1 charter", ->
			p = pc.ch("x")
			(expect (p pc.ps "x").match).toEqual "x"
			(expect (p pc.ps "xyz").match).toEqual "x" 
			(expect (p pc.ps "yzx").match).toEqual null

			p = pc.ch("0")
			(expect (p pc.ps "0").match).toEqual "0"

		it "match 1 of charter arguments", ->
			p = pc.ch("xyz")
			(expect (p pc.ps "x").match).toEqual "x"
			(expect (p pc.ps "xyz").match).toEqual "x"
			(expect (p pc.ps "yzx").match).toEqual "y"
			(expect (p pc.ps "z").match).toEqual "z"
			(expect (p pc.ps "a").match).toEqual null

		it "save last fail pos", ->
			p = pc.ch("xyz")
			(expect (p pc.ps "12345x", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345y", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345z", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "12345y", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345 y", 5).state.lastFailPos).toEqual 5


	describe "range", ->

		it "match charter in range", ->
			p = pc.range("a", "z")
			(expect (p pc.ps "x3").match).toEqual "x"
			(expect (p pc.ps "a1").match).toEqual "a"
			(expect (p pc.ps "z2").match).toEqual "z"
			(expect (p pc.ps "A3").match).toEqual null
			(expect (p pc.ps "Z4").match).toEqual null
			(expect (p pc.ps "X3").match).toEqual null
			(expect (p pc.ps "16").match).toEqual null

		it "save last fail pos", ->
			p = pc.range("a", "z")
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "123456 xy ", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "123456fz ", 7).state.lastFailPos).toEqual null


	describe "space", ->

		it "match space", ->
			p = pc.space()
			(expect (p pc.ps " abc").match).toEqual " "
			(expect (p pc.ps "\tabc").match).toEqual "\t"
			(expect (p pc.ps "\rabc").match).toEqual "\r"
			(expect (p pc.ps "\n\tabc").match).toEqual "\n\t"
			(expect (p pc.ps "abc").match).toEqual null
			(expect (p pc.ps "").match).toEqual null

		it "save last fail pos", ->
			p = pc.space()
			(expect (p pc.ps "12345 ", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "1234567", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "123456  ", 7).state.lastFailPos).toEqual null


	describe "ws", ->

		it "match something with space before it", ->
			p = pc.ws(pc.tok "abc")
			(expect (p pc.ps " \t\nabc").match).toEqual "abc"
			(expect (p pc.ps "abc").match).toEqual "abc"

		it "save last fail pos", ->
			p = pc.ws(pc.tok "abc")
			(expect (p pc.ps "12345 abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "1234567\t\nabc", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "123456  \n\n\n\n\nabc", 7).state.lastFailPos).toEqual null


	describe "choice", ->

		it "match 1 of given patterns", ->
			p = pc.choice pc.tok("abc"), pc.ch("xyz"), pc.range("1","3")
			(expect (p pc.ps "y").match).toEqual "y"
			(expect (p pc.ps "abc").match).toEqual "abc"
			(expect (p pc.ps "2").match).toEqual "2"
			(expect (p pc.ps "4").match).toEqual null
			(expect (p pc.ps " abc").match).toEqual null

		it "save last fail pos", ->
			p = pc.choice pc.tok("abc"), pc.ch("xyz"), pc.range("1","3")
			(expect (p pc.ps "12345abcd", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "1234567\t\nabc", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "12345672", 7).state.lastFailPos).toEqual null


	describe "seq", ->

		it "match patterns sequence", ->
			p = pc.seq pc.tok("abc"), pc.space(), pc.ch("xyz"), pc.range("0","3")
			(expect (p pc.ps "abc y0").match).toEqual ["abc"," ","y","0"]
			(expect (p pc.ps "abc y").match).toEqual null
			(expect (p pc.ps "0abc y1").match).toEqual null

		it "save last fail pos", ->
			p = pc.seq pc.tok("abc"), pc.space(), pc.ch("xyz"), pc.range("1","3")
			(expect (p pc.ps "12345abc y1", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345abc a1", 5).state.lastFailPos).toEqual 9
			(expect (p pc.ps "12345abc y0", 5).state.lastFailPos).toEqual 10


	describe "optional", ->

		it "match optional pattern", ->
			p = pc.optional pc.tok("abc")
			(expect (p pc.ps "abc").match).toEqual "abc"
			(expect (p pc.ps "abcdefg ").match).toEqual "abc"
			(expect (p pc.ps " abcdefg ").match).toEqual true

			pseq = pc.seq p, pc.space(), pc.ch("xyz"), pc.range("1","3")
			(expect (pseq pc.ps "abc y1").match).toEqual ["abc"," ","y","1"]
			(expect (pseq pc.ps " y1").match).toEqual [true," ","y","1"]
			(expect (pseq pc.ps "x y1").match).toEqual null

		it "save last fail pos", ->
			p = pc.optional pc.tok("abc")
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345xyz", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345", 4).state.lastFailPos).toEqual null


	describe "rep0", ->

		it "match pattern 0 more times", ->
			p = pc.rep0 pc.tok("abc")
			(expect (p pc.ps "abcdef").match).toEqual ["abc"]
			(expect (p pc.ps "abcabcdef").match).toEqual ["abc", "abc"]
			(expect (p pc.ps "adef").match).toEqual []

		it "save last fail pos", ->
			p = pc.rep0 pc.tok("abc")
			(expect (p pc.ps "12345abcabc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345abcabc", 6).state.lastFailPos).toEqual null


	describe "rep1", ->

		it "match pattern 1 more times", ->
			p = pc.rep1 pc.tok("abc")
			(expect (p pc.ps "abcdef").match).toEqual ["abc"]
			(expect (p pc.ps "abcabcdef").match).toEqual ["abc", "abc"]
			(expect (p pc.ps "adef").match).toEqual null

		it "save last fail pos", ->
			p = pc.rep1 pc.tok("abc")
			(expect (p pc.ps "12345abcabc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345abcabc", 6).state.lastFailPos).toEqual 6


	describe "neg", ->

		it "match 1 char with negative pattern", ->
			p = pc.neg pc.tok("abc")
			(expect (p pc.ps "abc").match).toEqual null
			(expect (p pc.ps "abcd").match).toEqual null
			(expect (p pc.ps " abc").match).toEqual " "
			(expect (p pc.ps "1abc").match).toEqual "1"

		it "save last fail pos", ->
			p = pc.neg pc.tok("abc")
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual 5
			(expect (p pc.ps "12345", 5).state.lastFailPos).toEqual 5
			(expect (p pc.ps "123456", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "1234", 5).state.lastFailPos).toEqual 5
			(expect (p pc.ps "123", 5).state.lastFailPos).toEqual 5


	describe "map", ->

		it "map matched with a function", ->
			p = pc.map pc.tok("abc"), (m)-> m+"def"
			(expect (p pc.ps "abc").match).toEqual "abcdef"
			(expect (p pc.ps "123").match).toEqual null

		it "save last fail pos", ->
			p = pc.map pc.tok("abc"), (m)-> m+"def"
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345xyz", 5).state.lastFailPos).toEqual 5


	describe "end", ->

		it "match no string", ->
			p = pc.end()
			(expect (p pc.ps "abc").match).toEqual null
			(expect (p pc.ps "").match).toEqual true

		it "save last fail pos", ->
			p = pc.end()
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual 5
			(expect (p pc.ps "12345", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "1234", 5).state.lastFailPos).toEqual 5


	describe "lazy", ->

		it "for break cyclic depend define", ->
			x = null
			p = pc.lazy -> x
			x = pc.tok("123")
			(expect (p pc.ps "123").match).toEqual "123"
			(expect (p pc.ps "abc").match).toEqual null

		it "save last fail pos", ->
			x = null
			p = pc.lazy -> x
			x = pc.tok("abc")
			(expect (p pc.ps "12345abc", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "123456 abcdefg ", 6).state.lastFailPos).toEqual 6
			(expect (p pc.ps "123456 abcdefg ", 7).state.lastFailPos).toEqual null


	describe "and", ->

		it "match all pattern", ->
			p = pc.and pc.range("a","z"), pc.ch("xyz")
			(expect (p pc.ps "z").match).toEqual "z"
			(expect (p pc.ps "a").match).toEqual null
			(expect (p pc.ps "X").match).toEqual null

		it "save last fail pos", ->
			p = pc.and pc.ch("xyz"), pc.range("a","z")
			(expect (p pc.ps "12345x", 5).state.lastFailPos).toEqual null
			(expect (p pc.ps "12345X", 5).state.lastFailPos).toEqual 5
			(expect (p pc.ps "12345a", 5).state.lastFailPos).toEqual 5




