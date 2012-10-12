pc = require "../pc"
ast = require "./ast"
parser = require "./parser"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


parse = (s) ->
  src = new pc.Source s, null
  parser.parse src


describe "Flow AST", ->

  describe "block", ->

  describe "toStr()", ->

    it "number", ->
      (expect (parse "1 2 3").toStr()).toEqual "[ 1 2 3 ]"


    it "string", ->
      (expect (parse "\"a\" \"b\" \"c\"").toStr()).toEqual "[ \"a\" \"b\" \"c\" ]"


    it "block", ->
      (expect (parse "a: [ b: a c: { x y >> a } + ] 1 2 a").toStr()).toEqual "[ a: [ b: a c: { x y >> a } + ] 1 2 a ]"


  describe "serialize", ->

    it "word", ->
      w = (parse "a").seq[0]
      d = w.serialize()
      (expect d.nodeType).toEqual "Word"
      w1 = new ast[d.nodeType] d.entry, d.refines, d.opt
      d1 = w1.serialize()
      s = JSON.stringify d
      s1 = JSON.stringify d1
      (expect s).toEqual s1


    it "block", ->
      b = (parse "a: [ b: a c: { x y >> a } + ] 1 2 a")
      d = b.serialize()
      b1 = new ast[d.nodeType] d.args, d.wordSeq, d.seq, d.elemType
      d1 = b1.serialize()
      s = JSON.stringify d
      s1 = JSON.stringify d1
      (expect s).toEqual s1







