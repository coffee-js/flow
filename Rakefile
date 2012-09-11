require 'rubygems'
require 'rake'
require 'pp'

CoffeeCmd = 'coffee'
arch = RbConfig::CONFIG['arch']
if arch =~ /^win/ || arch =~ /^mingw/
  CoffeeCmd = 'coffee.cmd'
end
SrvJsDir = "js"
SrvJsLibDir = "#{SrvJsDir}/lib"
CliJsDir = "public/js/lib"

def compile opt, outdir
 	sh "#{CoffeeCmd} #{opt} -o #{outdir} coffee"
end

src = Dir["coffee/**/*.coffee"]
js = src.map do |f|
  f.ext("js").sub(/^coffee/, CliJsDir)
end

desc 'Continually compile #{SrvJsLibDir}/ from coffee/'
task :watch do |t|
  compile '-cw', SrvJsLibDir
end

desc 'compile #{SrvJsLibDir}/ && #{CliJsDir}/ from coffee/'
task :compile => src do
  compile '-c', SrvJsLibDir
  compile '-bc', CliJsDir
end

desc 'compile #{SrvJsDir}/app/ from server/'
task :compile_srv => src do
  sh "#{CoffeeCmd} -c -o #{SrvJsDir}/app/ server/server.coffee"
end

desc 'Run test'
task :test do |t|
  sh "#{CoffeeCmd} ./test"
end

desc 'Run spec test'
task :spec do |t|
	sh "jasmine-node --coffee coffee"
end

desc 'Run auto spec test in node.js'
task :autocmd do |t|
	sh "jasmine-node --autotest --coffee coffee"
end

desc 'Run server'
task :auto => %w[compile_srv] do
  sh "node server.js"
end

task :default => :compile
