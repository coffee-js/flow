parser = require "./parser"
ast = require "./ast"
interp = require "./interp"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


src = (s) ->
  new ast.Source s, null


describe "Flow Interp", ->

  describe "buildin words", ->

    it "math OPs", ->
      s = src("1 2 -")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [-1]

      s = src("1 2 - 3 - 20")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [-4, 20]

      s = src("1 2 + 3 4 - *")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [-3]

      s = src("n: 1 ; n 2 -")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [-1]


    it "if function", ->
      s = src("1 2 > [ 1 2 + ] [ 3 4 + ] if")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [7]

      s = src("1 [ 1 2 + ] [ 3 4 + ] if")
      seq = (parser.parse s).match
      (expect (-> interp.eval seq, s)).toThrow "1:23 cond is not a boolean: 1"


  describe "word call", ->

    it "basic", ->
      s = src("add: [ a b >> a b + ] ; 1 2 add")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [3]

      s = src("fib: [ n >> n 1 = n 0 = or ] ; 2 fib 1 fib")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [false, true]

      s = src("x: 2 y: 3 x y *")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [2, 3, 6]

      s = src("x: [ n >> n 1 + ] ; 0 x")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [1]

      s = src("x: [ n >> n 1 + ] ; n: 1 0 x")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [1, 1]


    it "recursion call", ->
      s = src("fib: [ n >> n 2 < [ n ] [ n 1 - fib n 2 - fib + ] if ] ; 10 fib")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [55]

      s = src("fib: [ n >> n 1 = n 0 = or [ 1 ] [ n 1 - fib n 2 - fib + ] if ] ; 10 fib")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual [89]


    it "external call", ->
      s = src("\"hello world!\" console.log ;")
      seq = (parser.parse s).match
      (expect (interp.eval seq, s)).toEqual []










