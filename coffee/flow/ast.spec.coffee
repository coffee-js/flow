pc = require "../pc"
ast = require "./ast"
parser = require "./parser"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


parse = (s) ->
  src = new pc.Source s, null
  parser.parse src


describe "Flow AST", ->

  # describe "block", ->

  # describe "toStr()", ->

  #   it "number", ->
  #     (expect (parse "1 2 3").toStr()).toEqual "[ 1 2 3 ]"


  #   it "string", ->
  #     (expect (parse "\"a\" \"b\" \"c\"").toStr()).toEqual "[ \"a\" \"b\" \"c\" ]"


  #   it "block", ->
  #     (expect (parse "a: [ b: a c: { x y >> a } + ] 1 2 a").toStr()).toEqual "[ a: [ b: a c: { x y >> a } + ] 1 2 a ]"






