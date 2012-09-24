pc = require "../pc"
parser = require "./parser"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, "  "



CodeMirror.defineMode 'flow', (config) ->

  {
    startState: ->
      pos: 0

    token: (stream, state) ->

  }


CodeMirror.defineMIME('text/x-flow', 'flow')







