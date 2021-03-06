pc = require "../pc"
parser = require "./parser"


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, "  "


words = {
  ">>": "keyword"
  "true": "atom"
  "false": "atom"
  "do": "buildin"
  "if": "buildin"
  "len": "buildin"
  "slice": "buildin"
  "join": "buildin"
}


CodeMirror.defineMode 'flow', (config) ->

  tokenSeq = (stream, state) ->
    ch = stream.next()
    switch ch
      when ":"
        "commit"
      when ".", "#", "!"
        "keyword"
      when '"'
        state.tokenize = tokenString
        state.tokenize stream, state
      when "{"
        state.tokenize = tokenBlock
        "bracket"
      when "}"
        "bracket"
      when "["
        state.tokenize = tokenBlock
        "bracket"
      when "]"
        "bracket"
      else
        if /\d/.test ch
          stream.eatWhile /[\d]/
          if stream.eat "."
            stream.eatWhile /[\d]/
          "number"
        else
          stream.eatWhile /[^\s\[\]\{\}:\.#!]/
          cur = stream.current()
          if stream.peek() == ":"
            "tag"
          else if words[cur] != undefined
            words[cur]
          else
            "variable"

  tokenString = (stream, state) ->
    escaped = false
    ch = stream.next()
    while ch != undefined
      if ch == '"' && !escaped
        state.tokenize = tokenSeq
        break
      if ch == "\\"
        escaped = !escaped
      else
        escaped = false
      ch = stream.next()
    "string"

  tokenBlock = (stream, state) ->
    tokenSeq stream, state

  {
    startState: ->
      tokenize: tokenSeq

    token: (stream, state) ->
      if stream.eatSpace()
        null
      else
        state.tokenize stream, state
  }


CodeMirror.defineMIME('text/x-flow', 'flow')







