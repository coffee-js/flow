pc = exports


log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '


class Source
  constructor: (@txt, @path) ->

  lineCol: (pos)->
    line = 1
    lastLinePos = 0
    while lastLinePos = 1+@txt[0...pos].indexOf("\n",lastLinePos)
      ++line
    col = pos - lastLinePos + 1
    return [line, col]

pc.Source = Source


class ParserState
  constructor: (@src, @pos=0, @lastFailPos=null) ->

  forward: (n) ->
    new ParserState @src, @pos+n, @lastFailPos

  fail: ->
    new ParserState @src, @pos, @pos

  txt: ->
    @src.txt


class ParserReturn
  constructor: (@state, @match) ->


pc.ps = ->
  new ParserState arguments...

pc.ret = ->
  new ParserReturn arguments...

pc.tok = (s) ->
  (st) ->
    if st.txt().length-st.pos >= s.length && st.txt().slice(st.pos, st.pos+s.length) == s
      pc.ret st.forward(s.length), s
    else pc.ret st.fail(), null

pc.ch = (chs) ->
  (st) ->
    if st.txt().length-st.pos >= 1
      c = st.txt()[st.pos]
      for c1 in chs
        if c == c1[0]
          return pc.ret st.forward(1), c
      pc.ret st.fail(), null
    else pc.ret st.fail(), null

pc.range = (lower, upper) ->
  (st) ->
    if st.txt().length-st.pos >= 1
      c = st.txt()[st.pos]
      if c >= lower && c <= upper
        pc.ret st.forward(1), c
      else pc.ret st.fail(), null
    else pc.ret st.fail(), null

pc.regexp = (regexp) ->
  (st) ->
    m = st.txt().slice(st.pos, st.txt().length).match regexp
    if m != null
      pc.ret st.forward(m[0].length), m[0]
    else pc.ret st.fail(), null

pc.space = ->
  pc.regexp /^\s+/

pc.binaryNumber = ->
  pc.regexp /^(?:[-+]i|[-+][01]+#*(?:\/[01]+#*)?i|[-+]?[01]+#*(?:\/[01]+#*)?@[-+]?[01]+#*(?:\/[01]+#*)?|[-+]?[01]+#*(?:\/[01]+#*)?[-+](?:[01]+#*(?:\/[01]+#*)?)?i|[-+]?[01]+#*(?:\/[01]+#*)?)(?=[()\s;"]|$)/i

pc.octalNumber = ->
  pc.regexp /^(?:[-+]i|[-+][0-7]+#*(?:\/[0-7]+#*)?i|[-+]?[0-7]+#*(?:\/[0-7]+#*)?@[-+]?[0-7]+#*(?:\/[0-7]+#*)?|[-+]?[0-7]+#*(?:\/[0-7]+#*)?[-+](?:[0-7]+#*(?:\/[0-7]+#*)?)?i|[-+]?[0-7]+#*(?:\/[0-7]+#*)?)(?=[()\s;"]|$)/i

pc.hexNumber = ->
  pc.regexp /^(?:[-+]i|[-+][\da-f]+#*(?:\/[\da-f]+#*)?i|[-+]?[\da-f]+#*(?:\/[\da-f]+#*)?@[-+]?[\da-f]+#*(?:\/[\da-f]+#*)?|[-+]?[\da-f]+#*(?:\/[\da-f]+#*)?[-+](?:[\da-f]+#*(?:\/[\da-f]+#*)?)?i|[-+]?[\da-f]+#*(?:\/[\da-f]+#*)?)(?=[()\s;"]|$)/i

pc.decimalNumber = ->
  pc.regexp /^(?:[-+]i|[-+](?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*)i|[-+]?(?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*)@[-+]?(?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*)|[-+]?(?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*)[-+](?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*)?i|(?:(?:(?:\d+#+\.?#*|\d+\.\d*#*|\.\d+#*|\d+)(?:[esfdl][-+]?\d+)?)|\d+#*\/\d+#*))(?=[()\s;"]|$)/i

pc.ws = (p) ->
  (st) ->
    m = st.txt().slice(st.pos, st.txt().length).match /^\s+/
    nst = st
    if m != null
      nst = st.forward m[0].length
    return p(nst)

pc.choice = ->
  parsers = (p for p in arguments)
  (st) ->
    r = null
    a = []
    for p in parsers
      r = p st
      if r.match != null
        return r
      a.push r
    last = r
    for r in a
      if last.state.lastFailPos < r.state.lastFailPos
        last = r
    return last

pc.number = ->
  pc.choice pc.binaryNumber(), pc.octalNumber(), pc.hexNumber(), pc.decimalNumber()

pc.seq = ->
  parsers = (p for p in arguments)
  (st) ->
    nst = st
    a = []
    for p in parsers
      r = p nst
      if r.match == null
        return pc.ret r.state, null
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.optional = (p) ->
  (st) ->
    r = p st
    if r.match != null
      r
    else pc.ret st, true

pc.rep0 = (p) ->
  (st) ->
    nst = st
    a = []
    while (r = p(nst)).match != null
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.rep1 = (p) ->
  (st) ->
    r = p(st)
    if r.match == null
      return pc.ret r.state.fail(), null
    nst = r.state
    a = [r.match]
    while (r = p(nst)).match != null
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.neg = (p) ->
  (st) ->
    if st.txt().length-st.pos < 1
      return pc.ret st.fail(), null
    r = p st
    if r.match == null
      pc.ret st.forward(1), st.txt()[st.pos]
    else pc.ret st.fail(), null

pc.map = (p, f) ->
  (st) ->
    r = p st
    if r.match != null
      pc.ret r.state, f(r.match, st.pos, st.src)
    else pc.ret r.state.fail(), null

pc.end = ->
  (st) ->
    if st.pos == st.txt().length
      pc.ret st, true
    else pc.ret st.fail(), null

pc.lazy = (p) ->
  (st) ->
    p() st

pc.and = ->
  parsers = (p for p in arguments)
  p0 = parsers.shift()
  (st) ->
    r = p0 st
    if r.match != null
      for p1 in parsers
        r1 = p1 st
        if r1.match == null
          return pc.ret r.state.fail(), null
      r
    else pc.ret r.state.fail(), null






