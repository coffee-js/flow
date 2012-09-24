head ->
  meta charset: "utf-8"

  title "Flow REPL"

  script src: "/nowjs/now.js"
  script src: "/js/jquery.min.js"
  script src: "/js/require.js"

  link rel: "stylesheet", type: "text/css", href: "/codemirror/codemirror.css"
  script src: "/codemirror/codemirror.js"
  script src: "/codemirror/mode/javascript.js"
  link rel: "stylesheet", type: "text/css", href: "http://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin"
  link rel: "stylesheet", type: "text/css", href: "/css/repl.css"

body ->
  coffeescript ->
    requirejs.config
      baseUrl: "/public/js/lib"

    requirejs [
      #"flow/codemirror",
    ], ->
      editor = CodeMirror $("body")[0], {
        mode: "text/x-flow"
        lineNumbers: true
        matchBrackets: true
        indentWithTabs: true
        tabSize: 2
        indentUnit: 2
        tabMode: "indent"
      }
      ee = editor.getWrapperElement()
      ee.style.position = "absolute"
      ee.style.width = window.innerWidth + "px"
      ee.style.height = window.innerHeight + "px"

      window.addEventListener 'resize', (e) ->
        ee.style.width = window.innerWidth + "px"
        ee.style.height = window.innerHeight + "px"

      editor.setValue ""


coffeescript ->
  now.ready ->















