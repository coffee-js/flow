doctype 5

meta charset: "utf-8"
script src: "/nowjs/now.js"

coffeescript ->
  now.ready ->
    # now.name = prompt "What's your name?", ""

  now.retest = ->
    # location.reload()
    location.replace location.href

html ->
  @body



