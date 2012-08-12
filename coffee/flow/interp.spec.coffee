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
      seq = (parser.parse src("1 2 -")).match
      (expect (interp.eval seq)).toEqual [-1]

      seq = (parser.parse src("1 2 - 3 - 20")).match
      (expect (interp.eval seq)).toEqual [-4, 20]

      seq = (parser.parse src("1 2 + 3 4 - *")).match
      (expect (interp.eval seq)).toEqual [-3]

      seq = (parser.parse src("n: 1 ; n 2 -")).match
      (expect (interp.eval seq)).toEqual [-1]


    it "if function", ->
      seq = (parser.parse src("1 2 > [ 1 2 + ] [ 3 4 + ] if")).match
      (expect (interp.eval seq)).toEqual [7]


  describe "word call", ->

    it "basic", ->
      seq = (parser.parse src("add: [ a b >> a b + ] ; 1 2 add")).match
      (expect (interp.eval seq)).toEqual [3]

      seq = (parser.parse src("fib: [ n >> n 1 = n 0 = or ] ; 2 fib 1 fib")).match
      (expect (interp.eval seq)).toEqual [false, true]

      seq = (parser.parse src("x: 2 y: 3 x y *")).match
      (expect (interp.eval seq)).toEqual [2, 3, 6]

      seq = (parser.parse src("x: [ n >> n 1 + ] ; 0 x")).match
      (expect (interp.eval seq)).toEqual [1]

      seq = (parser.parse src("x: [ n >> n 1 + ] ; n: 1 0 x")).match
      (expect (interp.eval seq)).toEqual [1, 1]


    it "recursion call", ->
      seq = (parser.parse src("fib: [ n >> n 2 < [ n ] [ n 1 - fib n 2 - fib + ] if ] ; 10 fib")).match
      (expect (interp.eval seq)).toEqual [55]

      seq = (parser.parse src("fib: [ n >> n 1 = n 0 = or [ 1 ] [ n 1 - fib n 2 - fib + ] if ] ; 10 fib")).match
      (expect (interp.eval seq)).toEqual [89]


    it "external call", ->
      seq = (parser.parse src("\"hello world!\" console.log ;")).match
      (expect (interp.eval seq)).toEqual []










