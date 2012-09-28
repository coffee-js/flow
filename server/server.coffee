express = require "express"
util     = require "util"
ck      = require "coffeekup"
watchr  = require "watchr"
coffee  = require "coffee-script"
jasmine = require "jasmine-node"
fs      = require "fs"
path    = require "path"
walkdir = require "walkdir"
now     = require "now"
stylus  = require "stylus"
exec    = (require "child_process").exec
spawn   = (require "child_process").spawn


puts = (s) -> util.puts s
log = (s) -> console.log s
pp = (s) -> console.log JSON.stringify s, null, '  '
write = (s) -> process.stdout.write s

onWindows = ->
  process.platform.match /^win/i


publicDir = "public"
viewsDir = "server/views"


app = module.exports = express.createServer()

app.configure ->
  app.set "views", "server/views"
  app.set "view engine", "coffee"
  app.register ".coffee", ck.adapters.express
  #app.set "view options", layout: false
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static publicDir

app.configure "development", ->
  app.use express.errorHandler { dumpExceptions: true, showStack: true }

app.configure "production", ->
  app.use express.errorHandler()


srcDir = "coffee"
stylDir = "stylus"
CommJsDir = "js/lib"
jsDir = "#{publicDir}/js"
jsLibDir = "#{jsDir}/lib"
cssDir = "#{publicDir}/css"


scanDir = (dir, matcher) ->
  srcs = []
  walkdir.sync dir, (f, stat) ->
    try
      f = f.replace path.resolve(dir), dir
      if fs.statSync(f).isFile()
        if !/.*node_modules.*/i.test(f) && matcher.test(path.basename f)
          #util.puts "find: \"#{f}\""
          srcs.push f
    catch err
      util.puts "walkdir err: #{err}"
  srcs


# getJsSrcs = ->
#   a = scanDir jsLibDir, /\.js$/i
#   "/"+e for e in a

# getJsSpecs = ->
#   a = scanDir jsLibDir, /\.spec\.js$/i
#   "/"+e for e in a

# jsSrcs  = getJsSrcs()
# jsSpecs = getJsSpecs()


app.get "/", (req, resp) ->
	resp.render "index"
    # locals:
    #   srcs:  jsSrcs
    #   specs: jsSpecs

# app.get "/:name", (req, resp) ->
#   resp.render req.params.name


readJS = (path, res) ->
  fs.readFile path, "utf8", (err, data) ->
    if err
      util.puts "read file: #{path} error: #{err}"
    else if /\.js$/i.test path
      mod = "define(function(require, exports, module) {\n#{data}\nreturn exports;\n});"
      res.send mod, "Content-Type":"application/javascript"


app.get "/#{jsLibDir}/*", (req, res) ->
  readJS jsLibDir+"/"+req.params[0], res


port = 4321
app.listen port, ->
	util.puts "Listening on #{port}\nPress CTRL-C to stop server."


everyone = now.initialize app


if onWindows()
  coffeeCmd = "coffee.cmd" 
else
  coffeeCmd = "coffee"

if onWindows()
  jasmineCmd = "jasmine-node.cmd"
else
  jasmineCmd = "jasmine-node"

if onWindows()
  stylusCmd = "stylus.cmd"
else
  stylusCmd = "stylus"


everyone.now.commJsOut = ""

watchInCommJS = ->
  opts = ["--noColor", "--autotest", "--coffee", srcDir]
  a = opts.slice 0
  a.unshift jasmineCmd
  cmd = a.join " "
  puts cmd

  cc = spawn jasmineCmd, opts
  cc.stdout.on "data", (data) ->
    write "#{data}"
    everyone.now.commJsOut += "#{data}"
  cc.stderr.on "data", (data) ->
    write "#{data}"
    everyone.now.commJsOut += "#{data}"
  cc.on "exit", (code) ->
    puts "exec \"#{cmd}\" exited with code: #{code}"

watchInCommJS()


CompileState =
  COMPILING: "COMPILING"
  SUCCESSED: "SUCCESSED"
  FAILED:    "FAILED"

class CompileInfo
  constructor: (@state=CompileState.COMPILING, @errInfo = "")->
  reset: ->
    @state = CompileState.COMPILING
    @errInfo = ""

srcs = scanDir srcDir, /\.coffee$/i
# stylSrcs = scanDir stylDir, /\.styl$/i
# srcs = srcs.concat stylSrcs
compileInfoz = {}
for f in srcs
  compileInfoz[f] = new CompileInfo()


allCompileDone = ->
  for f, info of compileInfoz
    if info.state == CompileState.COMPILING
      return false
  true

compile = (f) ->
  if      f.match /\.coffee$/i
    compileJS f
  else if f.match /\.styl$/i
    compileCSS f


compileComm = (cmd, f) ->
  compileInfoz[f].reset()

  everyone.now.commJsOut = ""
  exec cmd, (err, stdout, stderr) ->
    compileInfoz[f].state = CompileState.COMPILING
    if err
      puts "exec \"#{cmd}\" error: #{err}"
    if stdout
      puts "stdout: #{stdout}"
    if stderr
      puts "stderr: #{stderr}"

    if err
      compileInfoz[f].state = CompileState.FAILED
      errInfo = "exec \"#{cmd}\" error: #{err}\nstderr: #{stderr}\n"
      compileInfoz[f].errInfo = errInfo
    else
      compileInfoz[f].state = CompileState.SUCCESSED

    if allCompileDone()
      puts "ALL COMPILE DONE"
      msg = ""
      for f, info of compileInfoz
        if info.state == CompileState.FAILED
          msg += info.state.errInfo
      if msg.length > 0
        everyone.now.empty?()
        everyone.now.printErr? errInfo
      else
        everyone.now.retest?()


compileCSS = (f) ->
  dirname = path.dirname f
  outdir = dirname.replace (new RegExp "^#{stylDir}", "i"), cssDir

  opts = ["-o", outdir, f]
  a = opts.slice 0
  a.unshift stylusCmd
  cmd = a.join " "
  puts cmd

  compileComm cmd, f


compileJS = (f) ->
  dirname = path.dirname f
  outdir = dirname.replace (new RegExp "^#{srcDir}", "i"), jsLibDir

  opts = ["-bc", "-o", outdir, f]
  a = opts.slice 0
  a.unshift coffeeCmd
  cmd = a.join " "
  puts cmd

  # errInfo = ""
  # cc = spawn coffeeCmd, opts
  # cc.stdout.on "data", (data) ->
  #   puts "stdout: #{data}"
  # cc.stderr.on "data", (data) ->
  #   puts "stderr: #{data}"
  #   errInfo += data
  # cc.on "exit", (code) ->
  #   if code
  #     puts "exec \"#{cmd}\" exited with code: #{code}"
  #     everyone.now.empty?()
  #     everyone.now.printErr? "exec \"#{cmd}\" exited with code: #{code}\nstderr: #{errInfo}\n"
  #   else
  #     everyone.now.retest?()

  compileComm cmd, f


for f, info of compileInfoz
  compile f


watchr.watch
  paths: [srcDir, stylDir]

  next: (err, watcher) ->
    if err
    	throw err
    util.puts "watching srcdir: \"#{srcDir}\""
  
  listener: (e, file, curr, prev) ->
    if onWindows()
      file = file.replace /\\/g, "/"
    util.puts "#{e}: \"#{file}\""
    if /\.(coffee|styl)$/i.test file
      if "new" == e
        if !compileInfoz[file]
          compileInfoz[file] = new CompileInfo()
        compile file
      if "change" == e
        compile file
      if "unlink" == e
        delete compileInfoz[file]


watchr.watch
  path: viewsDir

  next: (err, watcher) ->
    if err
      throw err
    util.puts "watching views dir: \"#{viewsDir}\""

  listener: (e, file, curr, prev) ->
    if onWindows()
      file = file.replace /\\/g, "/"
    util.puts "#{e}: \"#{file}\""
    if /\.coffee$/i.test file
      everyone.now.retest?()

watchr.watch
  path: publicDir

  next: (err, watcher) ->
    if err
      throw err
    util.puts "watching public dir: \"#{publicDir}\""

  listener: (e, file, curr, prev) ->
    if onWindows()
      file = file.replace /\\/g, "/"
    util.puts "#{e}: \"#{file}\""
    everyone.now.retest?()


everyone.connected ->
  util.puts "Joined: #{@now.name}"

everyone.disconnected ->
  util.puts "Left: #{@now.name}"



