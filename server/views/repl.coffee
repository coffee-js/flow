head ->
  meta charset: "utf-8"

  title "Flow REPL"

  script src: "/nowjs/now.js"
  script src: "/js/jquery.min.js"
  script src: "/js/require.js"

  link rel: "stylesheet", type: "text/css", href: "/codemirror/codemirror.css"
  script src: "/codemirror/codemirror.js"
  script src: "/codemirror/searchcursor.js"
  script src: "/codemirror/match-highlighter.js"
  script src: "/codemirror/mode/javascript.js"
  link rel: "stylesheet", type: "text/css", href: "http://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin"
  link rel: "stylesheet", type: "text/css", href: "/css/repl.css"

body ->
  div id: "wrapper"

  coffeescript ->
    requirejs.config
      baseUrl: "/public/js/lib"

    requirejs [
      "flow/codemirror",
    ], ->
      editor = CodeMirror $("#wrapper")[0], {
        mode: "text/javascript"
        #lineNumbers: true
        matchBrackets: true
        indentWithTabs: true
        smartIndent: true
        tabSize: 2
        indentUnit: 2
        tabMode: "indent"
        onCursorActivity: ->
          editor.matchHighlight "CodeMirror-matchhighlight"
      }
      editor.setValue ""


coffeescript ->
  now.ready ->















