pc = exports


class ParserState
  constructor: (@txt, pos, lastFailPos) ->
    @pos = pos ? 0
    @lastFailPos = lastFailPos ? @lastFailPos ? null

  forward: (n) ->
    new ParserState @txt, @pos+n, @lastFailPos

  fail: ->
    new ParserState @txt, @pos, @pos

class ParserReturn
  constructor: (@state, @match) ->


pc.ps = ->
  new ParserState arguments...

pc.ret = ->
  new ParserReturn arguments...

pc.tok = (s) ->
  (st) ->
    if st.txt.length-st.pos >= s.length && st.txt.substring(st.pos, st.pos+s.length) == s
      pc.ret st.forward(s.length), s
    else pc.ret st.fail(), null

pc.ch = (chs) ->
  (st) ->
    if st.txt.length-st.pos >= 1
      c = st.txt[st.pos]
      for c1 in chs
        if c == c1[0]
          return pc.ret st.forward(1), c
      pc.ret st.fail(), null
    else pc.ret st.fail(), null

pc.range = (lower, upper) ->
  (st) ->
    if st.txt.length-st.pos >= 1
      c = st.txt[st.pos]
      if c >= lower && c <= upper
        pc.ret st.forward(1), c
      else pc.ret st.fail(), null
    else pc.ret st.fail(), null

pc.space = ->
  (st) ->
    m = st.txt.substring(st.pos, st.txt.length).match /^\s+/
    if m
      pc.ret st.forward(m[0].length), m[0]
    else pc.ret st.fail(), null

pc.ws = (p) ->
  (st) ->
    m = st.txt.substring(st.pos, st.txt.length).match /^\s+/
    nst = st
    if m
      nst = st.forward m[0].length
    return p(nst)

pc.choice = ->
  parsers = (p for p in arguments)
  (st) ->
    r = null
    for p in parsers
      r = p st
      if r.match
        break
    return r

pc.seq = ->
  parsers = (p for p in arguments)
  (st) ->
    nst = st
    a = []
    for p in parsers
      r = p nst
      if !r.match
        return pc.ret r.state, null
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.optional = (p) ->
  (st) ->
    r = p st
    if r.match
      r
    else pc.ret st, true

pc.rep0 = (p) ->
  (st) ->
    nst = st
    a = []
    while (r = p(nst)).match
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.rep1 = (p) ->
  (st) ->
    r = p(st)
    if !r.match
      return pc.ret st.fail(), null
    nst = r.state
    a = [r.match]
    while (r = p(nst)).match
      nst = r.state
      a.push r.match
    return pc.ret nst, a

pc.neg = (p) ->
  (st) ->
    if st.txt.length-st.pos < 1
      return pc.ret st.fail(), null
    r = p st
    if !r.match
      pc.ret st.forward(1), st.txt[st.pos]
    else pc.ret st.fail(), null

pc.map = (p, f) ->
  (st) ->
    r = p st
    if r.match
      pc.ret r.state, f(r.match, st.pos)
    else pc.ret st.fail(), null

pc.end = ->
  (st) ->
    if st.pos == st.txt.length
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
    if r.match
      for p1 in parsers
        r1 = p1 st
        if !r1.match
          return pc.ret st.fail(), null
      r
    else pc.ret st.fail(), null



