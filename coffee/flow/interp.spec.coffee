parser = require "./parser"
ast = require "./ast"
interp = require "./interp"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


describe "Fn Interp", ->

  describe "buildin words", ->

    it "math OPs", ->
      seq = (parser.parse "1 2 + 3 - 20").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [0, 20]

      seq = (parser.parse "1 2 + 3 4 - *").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [-3]


    it "if function", ->
      seq = (parser.parse "1 2 > [ 1 2 + ] [ 3 4 + ] if").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [7]


    it "word call", ->
      seq = (parser.parse "add: [ $-2 $-1 + ] 1 2 add").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [3]

      seq = (parser.parse "fib: [ n: $-1 1 = n 0 = or ] 2 fib").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [false]

      seq = (parser.parse "x: 2 y: 3 x y *").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [2, 3, 6]


    it "recursion call", ->
      seq = (parser.parse "fib: [ n: $-1 1 = n 0 = or [ 1 ] [ n 1 - fib n 2 - fib + ] if ] 10 fib").match
      (expect (interp.eval new ast.NodeBlock seq)).toEqual [1]

      # src = "fib: [ n: $-1 1 = n 0 = or [ 1 ] [ n 1 - fib n 2 - fib + ] if ] 10 fib"
      # seq = (parser.parse src).match
      # (expect (interp.eval new ast.NodeBlock seq)).toEqual [89]













