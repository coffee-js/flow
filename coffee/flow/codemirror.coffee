pc = require "../pc"
parser = require "./parser"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, "  "



CodeMirror.defineMode 'flow', (config) ->

  tokenBase = (stream, state) ->
    ch = stream.next()


  {
    startState: ->
      tokenize: tokenBase

    token: (stream, state) ->
      if stream.eatSpace()
        null
      else
        state.tokenize stream, state
  }


CodeMirror.defineMIME('text/x-flow', 'flow')







