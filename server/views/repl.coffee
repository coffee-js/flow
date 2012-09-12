head ->
  meta charset: "utf-8"

  title "Flow REPL"

  script src: "/nowjs/now.js"
  script src: "/js/jquery.min.js"
  script src: "/js/require.js"

  link rel: "stylesheet", type: "text/css", href: "/codemirror/codemirror.css"
  script src: "/codemirror/codemirror.js"
  link rel: "stylesheet", type: "text/css", href: "http://fonts.googleapis.com/css?family=Ubuntu:regular,bold&subset=Latin"
  link rel: "stylesheet", type: "text/css", href: "/css/repl.css"

body ->
  textarea id: "code", ->

  coffeescript ->
    editor = CodeMirror.fromTextArea $("#code")[0], {
      lineNumbers: true
      matchBrackets: true
      indentWithTabs: true
      tabSize: 2
      indentUnit: 2
    }


coffeescript ->
  now.ready ->















