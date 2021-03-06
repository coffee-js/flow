head ->
  meta charset: "utf-8"

  title "Jasmine Spec Server"

  script src: "/nowjs/now.js"
  script src: "/js/jquery.min.js"
  script src: "/js/require.js"

  link rel: "stylesheet", type: "text/css", href: "/jasmine/jasmine.css"
  script src: "/jasmine/jasmine.js"
  script src: "/jasmine/jasmine-html.js"
  link rel: "stylesheet", type: "text/css", href: "http://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin"

body ->
  coffeescript ->
    requirejs.config
      baseUrl: "/public/js/lib"

    requirejs [
      "pc.spec",
      "flow/ast.spec",
      "flow/parser.spec",
      "flow/interp.spec",
    ], ->
      jasmine.getEnv().addReporter new jasmine.TrivialReporter()
      #jasmine.getEnv().addReporter new jasmine.HtmlReporter()
      jasmine.getEnv().execute()

  div style: [
    "padding: 8px 13px"
    "background: white"
  ].join(";\n"), ->
    div
      style: [
        "color: black"
        "background: #FEF"
        "font-size: .9em"
        "font-family: Ubuntu, sans-serif"
        #"font-family: \"Menlo\", \"Monaco\", \"Courier New\", monospace"
        "margin: 5px 17px 5px 0"
        "padding: 2px 0 2px 10px"
      ].join(";"), ->
        span style: [
          "font-size: 1.1em"
          #"padding: 10px"
        ].join(";"), -> "NodeJS:"
        pre id: "NodeJS-Console", style: [
          "font-size: .9em"
          "font-family: Ubuntu, sans-serif"
          #"padding: 10px"
        ].join(";"), -> ""

coffeescript ->
  now.ready ->
    # now.name = prompt "What's your name?", ""
    t = $("#NodeJS-Console")
    t.text now.commJsOut
    t.css "font-family", "Ubuntu, sans-serif"

    tp = $("#TrivialReporter")
    tp.css "position", "relative"
    tp.css "font-family", "Ubuntu, sans-serif"

  now.empty = ->
    $("body").empty()

  now.printErr = (s) ->
    id = "#error-info"
    t = $(id)
    if 0 == t.length
      t = $ "<div></div>"
      t.attr "id", id
      t.appendTo "body"
    t.text s










