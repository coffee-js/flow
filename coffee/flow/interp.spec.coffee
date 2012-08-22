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
        expect(run "1 2 > { 1 2 + } { 3 4 + } if").toEqual [7]

      it "type check", ->
        expect(-> run "1 { 1 2 + } { 3 4 + } if").toThrow "null:1:1 cond is not a boolean: 1"
        expect(-> run "1 2 > 3 { 3 4 + } if").toThrow "null:1:7 whenTrue is not a block: 3"


    describe "do block", ->

      it "basic", ->
        expect(run "{ 1 2 + } do").toEqual [3]
        expect(run "a: [ 2 + ] 1 [ a ]").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } do").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } [ do ]").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } [ f >> f ] do").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } [ v f >> v f ] do").toEqual [3]

      it "concatnative", ->
        expect(run "1 { 2 + } do").toEqual [3]
        expect(run "1 2 { + } do").toEqual [3]
        expect(run "1 2 { n >> n 2 + - } do").toEqual [-3]


  describe "word call", ->

    it "basic", ->
      expect(run "a: 20 a").toEqual [20]
      expect(run "add: [ a b >> a b + ] 1 2 add").toEqual [3]
      expect(run "fib: [ n >> n 1 = n 0 = or ] 2 fib 1 fib").toEqual [false, true]
      expect(run "x: 2 y: 3 x y *").toEqual [6]
      expect(run "x: [ n >> n 1 + ] 0 x").toEqual [1]
      expect(run "x: [ n >> n 1 + ] n: 1 0 x").toEqual [1]


    it "recursion call", ->
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 1 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 2 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 10 fib").toEqual [55]
      expect(run "fib: [ n >> n 1 = n 0 = or { 1 } { n 1 - fib n 2 - fib + } if ] 10 fib").toEqual [89]


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
      expect(run "{ a: 100 } a>").toEqual [100]
      expect(run "{ a: { b: 10 } } a> b>").toEqual [10]


    it "write named elem", ->
      expect(run "{ } 5 >a a>").toEqual [5]
      expect(run "{ a: { } } a> 200 >b b>").toEqual [200]


    it "read nth elem", ->
      expect(run "{ 100 } -1>").toEqual [100]
      expect(run "{ { 10 } } 1> 1>").toEqual [10]


    it "write nth elem", ->
      expect(run "{ } 5 >1 1>").toEqual [5]
      expect(run "{ { } } 1> 200 >1 1>").toEqual [200]
      expect(run "{ { 3 4 } } -1> 5 >-2 -2>").toEqual [5]


    it "slice", ->
      expect(run "{ 1 2 3 4 5 } 2 -2 slice 1>").toEqual [2]
      expect(run "{ 1 2 3 4 5 } len").toEqual [5]
      expect(run "{ 1 2 3 4 5 } 1 5 slice len").toEqual [5]
      expect(run "{ 1 2 3 4 5 } 1 -1 slice len").toEqual [5]


    it "num-words", ->
      expect(run "{ 1 2 3 4 5 } num-words").toEqual [0]
      expect(run "{ a: 1 b: 2 c: 3 } num-words").toEqual [3]
      expect(run "{ a: 1 b: 2 c: 3 a b c } num-words").toEqual [3]


    it "len", ->
      expect(run "{ 1 2 3 4 5 } len").toEqual [5]
      expect(run "{ a: 1 b: 2 c: 3 } len").toEqual [0]
      expect(run "{ a: 1 b: 2 c: 3 a b c } len").toEqual [3]


    it "num-elems", ->
      expect(run "{ 1 2 3 4 5 } num-elems").toEqual [5]
      expect(run "{ a: 1 b: 2 c: 3 } num-elems").toEqual [3]
      expect(run "{ a: 1 b: 2 c: 3 a b c } num-elems").toEqual [6]


    it "join", ->
      expect(run "{ 1 2 3 4 5 } { 6 7 8 9 10 } join num-elems").toEqual [10]
      expect(run "{ a: 1 b: 2 a b } { c: 3 d: 4 c d } join num-elems").toEqual [8]


    it "unshift", ->
      expect(run "{ 1 2 3 4 5 } 100 unshift 1>").toEqual [100]
      expect(run "{ 1 2 3 4 5 } 100 unshift len").toEqual [6]


  describe "simple function impl", ->

    filterFn = \
      "filter: [ a p >>
        x:  [ a 1> ]
        xs: [ a 2 -1 slice ]
        a len 0 = {
          a
        } {
          x p do {
            xs p filter x unshift
          } {
            xs p filter
          } if
        } if
      ]"
    it "filter impl", ->
      expect(run "#{filterFn} { 0 3 1 4 1 5 2 } { 3 <= } filter len").toEqual [5]
      expect(run "#{filterFn} { 0 3 5 4 1 5 2 } { 4 <= } filter len").toEqual [5]
      expect(run "#{filterFn} { 0 3 5 4 1 5 2 } { 4 <= } filter 1>").toEqual [0]
      expect(run "#{filterFn} { 0 3 5 4 1 5 2 } { 4 <= } filter 5>").toEqual [2]
      expect(run "#{filterFn} { 0 3 5 4 1 5 2 } { 0 <= } filter 1>").toEqual [0]
      expect(run "#{filterFn} { 0 3 5 4 1 5 2 } { 0 < } filter len").toEqual [0]


    qsortFn = \
      "qsort: [ a >>
        qivot: [ a 1> ]
        xs: [ a 2 -1 slice ]
        less: [ xs { qivot <= } filter qsort ]
        more: [ xs { qivot >  } filter qsort ]
        a len 0 = {
          a
        } {
          less more qivot unshift join
        } if
      ]"
    qsortFn1 = \
      "qsort: [ a >>
        qivot: [ a 1> ]
        less:  [ a { qivot < } filter qsort ]
        equal: [ a { qivot = } filter ]
        more:  [ a { qivot > } filter qsort ]
        a len 0 = {
          a
        } {
          less equal more join join
        } if
      ]"
    it "qsort impl", ->
      td = "12 100 5 34 27 10 -50 0"
      expect(run "#{filterFn} #{qsortFn} { #{td} } qsort len").toEqual [8]
      expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 1>").toEqual [-50]
      # expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 2>").toEqual [0]
      # expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 3>").toEqual [5]
      # expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 4>").toEqual [10]
      expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 5>").toEqual [12]
      # expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 6>").toEqual [27]
      # expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 7>").toEqual [34]
      expect(run "#{filterFn} #{qsortFn} { #{td} } qsort 8>").toEqual [100]

      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort len").toEqual [8]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 1>").toEqual [-50]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 2>").toEqual [0]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 3>").toEqual [5]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 4>").toEqual [10]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 5>").toEqual [12]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 6>").toEqual [27]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 7>").toEqual [34]
      # expect(run "#{filterFn} #{qsortFn1} { #{td} } qsort 8>").toEqual [100]







