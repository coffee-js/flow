pc = require "../pc"
parser = require "./parser"
ast = require "./ast"
interp = require "./interp"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


run = (txt) ->
  src = new pc.Source txt, null
  b = interp.eval (parser.parse src)
  b.seq.map (e) -> e.val


describe "Flow Interp", ->

  describe "data", ->

    it "basic", ->
      expect(run "1 2").toEqual [1, 2]


  describe "buildin words", ->

    describe "math OPs", ->

      it "basic", ->
        expect(run "1 2 -").toEqual [-1]
        expect(run "1 2 - 3 - 20").toEqual [-4, 20]
        expect(run "1 2 + 3 4 - *").toEqual [-3]
        expect(run "n: 1 n 2 -").toEqual [-1]


    describe "if function", ->

      it "basic", ->
        expect(run "1 2 > [ 1 2 + ] [ 3 4 + ] if").toEqual [7]

      it "type check", ->
        expect(-> run "1 [ 1 2 + ] [ 3 4 + ] if").toThrow "null:1:1 cond is not a boolean: 1"
        expect(-> run "1 2 > 3 [ 3 4 + ] if").toThrow "null:1:7 whenTrue is not a block: 3"


    describe "do block", ->

      it "basic", ->
        expect(run "[ 1 2 + ] do").toEqual [3]


      it "concatnative", ->
        expect(run "1 [ 2 + ] do").toEqual [3]
        expect(run "1 2 [ + ] do").toEqual [3]
        expect(run "1 2 [ n >> n 2 + - ] do").toEqual [-3]


  describe "word call", ->

    it "basic", ->
      expect(run "a: 20 a").toEqual [20]
      expect(run "add: [ a b >> a b + ] 1 2 add").toEqual [3]
      expect(run "fib: [ n >> n 1 = n 0 = or ] 2 fib 1 fib").toEqual [false, true]
      expect(run "x: 2 y: 3 x y *").toEqual [6]
      expect(run "x: [ n >> n 1 + ] 0 x").toEqual [1]
      expect(run "x: [ n >> n 1 + ] n: 1 0 x").toEqual [1]


    it "recursion call", ->
      expect(run "fib: [ n >> n 2 < [ n ] [ n 1 - fib n 2 - fib + ] if ] 1 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < [ n ] [ n 1 - fib n 2 - fib + ] if ] 2 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < [ n ] [ n 1 - fib n 2 - fib + ] if ] 10 fib").toEqual [55]
      expect(run "fib: [ n >> n 1 = n 0 = or [ 1 ] [ n 1 - fib n 2 - fib + ] if ] 10 fib").toEqual [89]


    it "external call", ->
      expect(run "\"hello world!\" js/console.log").toEqual ["hello world!"]


    it "concatnative", ->
      expect(run "a: [ 2 + ] 1 a").toEqual [3]
      expect(run "a: [ + ] 1 2 a").toEqual [3]
      expect(run "a: [ n >> n 2 + - ] 1 2 a").toEqual [-3]


    describe "scopes", ->

      it "word call word or block can only up block level", ->
        expect(run "b: [ c ] c: 100 d: [ a: b c: 10 a ] d").toEqual [100]
        expect(run "b: [ 1 c ] c: [ 2 + ] d: [ a: b c: [ 100 ] a ] d").toEqual [3]


  describe "block data access", ->

    it "read named elem", ->
      expect(run "[ a: 100 ] a>>").toEqual [100]
      expect(run "[ a: [ b: 10 ] ] a>> b>>").toEqual [10]


    it "write named elem", ->
      expect(run "[ ] 5 >>a a>>").toEqual [5]
      expect(run "[ a: [ ] ] a>> 200 >>b b>>").toEqual [200]


    it "read nth elem", ->
      expect(run "[ 100 ] -1>>").toEqual [100]
      expect(run "[ [ 10 ] ] 1>> 1>>").toEqual [10]


    it "write nth elem", ->
      expect(run "[ ] 5 >>1 1>>").toEqual [5]
      expect(run "[ [ ] ] 1>> 200 >>1 1>>").toEqual [200]
      expect(run "[ [ 3 4 ] ] -1>> 5 >>-2 -2>>").toEqual [5]






