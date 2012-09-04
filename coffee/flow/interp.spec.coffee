pc = require "../pc"
parser = require "./parser"
ast = require "./ast"
interp = require "./interp"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


run = (txt) ->
  src = new pc.Source txt, null
  b = interp.eval (parser.parse src)
  b.map (e) -> e.val



describe "Flow Interp", ->

  describe "data", ->

    it "basic", ->
      expect(run "1 2").toEqual [1, 2]


  describe "basic words", ->

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
        expect(-> run "1 { 1 2 + } { 3 4 + } if").toThrow "null:1:1 expect a boolean, got:[1:number]"
        expect(-> run "1 2 > 3 { 3 4 + } if").toThrow "null:1:7 expect a object, got:[3:number]"


    describe "eval block", ->

      it "basic", ->
        expect(run "{ 1 2 + } eval").toEqual [3]
        expect(run "a: [ 2 + ] 1 [ a ]").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } eval").toEqual [3]
        expect(run "a: [ 2 + ] 1 { a } [ eval ]").toEqual [3]


      it "concatnative", ->
        expect(run "1 { 2 + } eval").toEqual [3]
        expect(run "1 2 { + } eval").toEqual [3]



  describe "word call", ->

    it "basic", ->
      expect(run "a: 20 a").toEqual [20]


    it "define word no order in same scope", ->
      expect(run "b: [ c ] c: 100 b").toEqual [100]


    describe "scopes", ->

      it "word call word or block can only up block level", ->
        expect(run "b: [ c ] c: 100 d: [ a: b c: 10 a ] d").toEqual [100]
        expect(run "b: [ 1 c ] c: [ 2 + ] d: [ a: b c: [ 100 ] a ] d").toEqual [3]
        expect(run "b: c c: 100 d: [ a: b c: 10 a ] d").toEqual [100]


    it "seq curry call", ->
      expect(run "add: [ a b >> a b + ] 1 2 add").toEqual [3]
      expect(run "fib: [ n >> n 1 = n 0 = or ] 2 fib 1 fib").toEqual [false, true]
      expect(run "x: 2 y: 3 x y *").toEqual [6]
      expect(run "x: [ n >> n 1 + ] 0 x").toEqual [1]
      expect(run "a: [ 2 + ] 1 { a } [ f >> f ] eval").toEqual [3]
      expect(run "a: [ 2 + ] 1 { a } [ v f >> v f ] eval").toEqual [3]
      expect(run "1 2 { n >> n 2 + - } eval").toEqual [-3]


    it "not resolving arg word", ->
      expect(run "x: [ n >> n 1 + ] n: 1 0 x").toEqual [1]
      expect(run "x: [ - >> - 1 + ] n: 1 0 x").toEqual [1]


    it "recursion call", ->
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 1 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 2 fib").toEqual [1]
      expect(run "fib: [ n >> n 2 < { n } { n 1 - fib n 2 - fib + } if ] 10 fib").toEqual [55]
      expect(run "fib: [ n >> n 1 = n 0 = or { 1 } { n 1 - fib n 2 - fib + } if ] 10 fib").toEqual [89]


    it "concatnative", ->
      expect(run "a: [ 2 + ] 1 a").toEqual [3]
      expect(run "a: [ + ] 1 2 a").toEqual [3]
      expect(run "a: [ n >> n 2 + - ] 1 2 a").toEqual [-3]


    it "use \"'\" get val of a eval word", ->
      expect(run "add: [ a b >> a b + ] 1 2 'add eval").toEqual [3]
      expect(run "a: [ 2 + ] 1 'a eval ").toEqual [3]


    it "closure test", ->


  unshiftFn = "unshift: [ b e >> b 1 0 { e } splice ]"
  pushFn = "push: [ b e >> b b len 1 + 0 { e } splice ]"


  describe "basic block data access", ->

    it "read named elem", ->
      expect(run "{ a: 100 } \"a\" get").toEqual [100]
      expect(run "{ a: { b: 10 } } \"a\" get \"b\" get").toEqual [10]


    it "read nth elem", ->
      expect(run "{ 100 } -1 get").toEqual [100]
      expect(run "{ { 10 } } 1 get 1 get").toEqual [10]


    it "write named elem", ->
      expect(run "{ } 5 \"a\" set \"a\" get").toEqual [5]
      expect(run "{ a: { } } \"a\" get 200 \"b\" set \"b\" get").toEqual [200]


    it "write nth elem", ->
      expect(run "{ } 5 1 set 1 get").toEqual [5]
      expect(run "{ { } } 1 get 200 1 set 1 get").toEqual [200]
      expect(run "{ { 3 4 } } -1 get 5 -2 set -2 get").toEqual [5]


    it "read arg elem", ->
      expect(-> run "{ a >> + } \"a\" get").toThrow "null:1:12 no elem named:a in block [object Object]"


    it "write arg elem", ->
      expect(run "{ a >> + } 5 \"a\" set \"a\" get").toEqual [5]
      expect(run "{ a >> + } 5 \"a\" set word-count").toEqual [1]
      expect(run "{ a >> + } 5 \"a\" set count").toEqual [2]


    it "use \"'\" read val of a eval elem", ->
      expect(run "{ [ 100 ] } \"'-1\" get eval").toEqual [100]
      expect(run "{ a: [ 100 ] } \"'a\" get eval").toEqual [100]


    it "len", ->
      expect(run "{ 1 2 3 4 5 } len").toEqual [5]
      expect(run "{ a: 1 b: 2 c: 3 } len").toEqual [0]
      expect(run "{ a: 1 b: 2 c: 3 a b c } len").toEqual [3]


    it "word-count", ->
      expect(run "{ 1 2 3 4 5 } word-count").toEqual [0]
      expect(run "{ a: 1 b: 2 c: 3 } word-count").toEqual [3]
      expect(run "{ a: 1 b: 2 c: 3 a b c } word-count").toEqual [3]


    it "count", ->
      expect(run "{ 1 2 3 4 5 } count").toEqual [5]
      expect(run "{ a: 1 b: 2 c: 3 } count").toEqual [3]
      expect(run "{ a: 1 b: 2 c: 3 a b c } count").toEqual [6]


    it "slice", ->
      expect(run "{ 1 2 3 4 5 } 2 -2 slice eval").toEqual [2,3,4]
      expect(run "{ 1 2 3 4 5 } 1 5 slice eval").toEqual [1,2,3,4,5]
      expect(run "{ 1 2 3 4 5 } 1 -1 slice eval").toEqual [1,2,3,4,5]
      expect(run "{ 1 2 3 4 5 } 2 -1 slice eval").toEqual [2,3,4,5]


    it "join", ->
      expect(run "{ 1 2 3 4 5 } { 6 7 8 9 10 } join count").toEqual [10]
      expect(run "{ a: 1 b: 2 a b } { c: 3 d: 4 c d } join count").toEqual [8]


    it "splice", ->
      expect(run "{ 1 2 3 4 5 } 1 0 { 100 } splice eval").toEqual [100,1,2,3,4,5]
      expect(run "{ 1 2 3 4 5 } 2 2 { 100 } splice eval").toEqual [1,100,4,5]
      expect(run "x: 100 { 1 2 3 4 5 } 1 0 { x } splice eval").toEqual [100,1,2,3,4,5]
      expect(run "x: 100 { 1 2 3 4 5 } 2 2 { x } splice eval").toEqual [1,100,4,5]


    it "unshift", ->
      expect(run "#{unshiftFn} { 1 2 3 4 5 } 100 unshift eval").toEqual [100,1,2,3,4,5]
      expect(run "#{unshiftFn} x: 100 { 1 2 3 4 5 } x unshift eval").toEqual [100,1,2,3,4,5]


    it "push", ->
      expect(run "#{pushFn} { 1 2 3 4 5 } 100 push eval").toEqual [1,2,3,4,5,100]
      expect(run "#{pushFn} x: 100 { 1 2 3 4 5 } x push eval").toEqual [1,2,3,4,5,100]


  describe "simple function impl", ->

    filterFn = \
      "filter: [ a p >>
        x:  [ a 1 get ]
        xs: [ a 2 -1 slice ]
        a len 0 = {
          a
        } {
          x p eval {
            xs p filter x unshift
          } {
            xs p filter
          } if
        } if
      ]"
    it "filter impl", ->
      expect(run "#{unshiftFn} #{filterFn} { 1 } { 3 <= } filter eval").toEqual [1]
      expect(run "#{unshiftFn} #{filterFn} { 0 1 } { 3 < } filter eval").toEqual [0,1]
      expect(run "#{unshiftFn} #{filterFn} { 0 3 1 4 1 5 2 } { 3 <= } filter eval").toEqual [0,3,1,1,2]
      expect(run "#{unshiftFn} #{filterFn} { 0 3 5 4 1 5 2 } { 4 <= } filter eval").toEqual [0,3,4,1,2]
      expect(run "#{unshiftFn} #{filterFn} { 0 3 5 4 1 5 2 } { 0 < } filter eval").toEqual []


    qsortFn = \
      "qsort: [ a >>
        qivot: [ a 1 get ]
        xs:    [ a 2 -1 slice ]
        less:  [ xs { qivot <= } filter qsort ]
        more:  [ xs { qivot >  } filter qsort ]
        a len 0 = {
          a
        } {
          less more qivot unshift join
        } if
      ]"
    qsortFn1 = \
      "qsort: [ a >>
        qivot: [ a 1 get ]
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
      expect(run "#{unshiftFn} #{filterFn} #{qsortFn} { #{td} } qsort eval").toEqual [-50,0,5,10,12,27,34,100]
      expect(run "#{unshiftFn} #{filterFn} #{qsortFn1} { #{td} } qsort eval").toEqual [-50,0,5,10,12,27,34,100]



    it "ifte impl", ->

    it "genrec impl", ->

    it "linrec impl", ->

    it "binrec impl", ->


  describe "basic OO features", ->
    it "define object", ->
      expect(run "1 { a: [ b + ] b: 2 } \"a\" get").toEqual [3]
      expect(run "x: { a: [ b + ] b: 2 } 1 x \"a\" get").toEqual [3]


  describe "apply block", ->
    it "apply", ->
      expect(run "3 { a >> a 2 + } apply eval").toEqual [5]


    it "curry", ->
      expect(run "3 { a >> a 2 + } 1 curry eval").toEqual [5]
      expect(run "1 2 { + } { a >> a } 3 curry eval eval").toEqual [3]
      expect(run "3 { 1 + } 0 curry eval").toEqual [4]


    it "block read curry elem", ->
      expect(run "3 { a >> a 2 + } 1 curry \"a\" get").toEqual [3]


    it "curry OO features", ->
      expect(run "5 { a >> b: a } 1 curry \"b\" get").toEqual [5]
      expect(run "3 { a >> b: [ a 2 + ] } 1 curry \"b\" get").toEqual [5]
      expect(run "3 { a >> [ a 2 + ] } 1 curry 1 get").toEqual [5]


    it "auto curry OO features", ->
      expect(run "{ a >> b: { a 2 + } } \"b\" get word-count").toEqual [0]
      expect(run "1 { a >> b: [ a 2 + ] } \"b\" get").toEqual [3]
      expect(run "1 { a >> b: [ a >> a 2 + ] } \"b\" get").toEqual [3]
      expect(run "1 2 { a >> b: [ c >> a c + ] } \"b\" get").toEqual [3]
      expect(-> run "{ a >> b: [ 1 2 + ] } \"b\" get").toThrow "null:1:27 no enough elems in seq, seq.len:0 n:1"


    it "arg-word-count", ->
      expect(run "{ 1 2 3 4 5 } arg-word-count").toEqual [0]
      expect(run "{ a: 1 b: 2 c: 3 } arg-word-count").toEqual [0]
      expect(run "{ x y z >> a: 1 b: 2 c: 3 a b c } arg-word-count").toEqual [0]
      expect(run "10 20 30 { x y z >> a: 1 b: 2 c: 3 a b c } 2 curry arg-word-count").toEqual [10,2]


    it "wcurry", ->
      expect(run "{ a: 1 b: 2 c: 3 } { a b c >> a b c } wcurry eval").toEqual [1,2,3]
      expect(run "100 20 { b: 2 } { a b c >> a b c } wcurry eval").toEqual [100,2,20]


  it "external call", ->
    #expect(run "\"hello world!\" js/console.log").toEqual ["hello world!", undefined]






