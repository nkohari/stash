{spawn} = require 'child_process'

exec = (executable, args, callback) ->
	child = spawn executable, args
	child.stdout.pipe process.stdout
	child.stderr.pipe process.stderr
	child.on 'exit', (code) -> callback?() if code is 0

task 'build', 'Build lib/ from src/', ->
	exec './node_modules/coffee-script/bin/coffee', ['-c', '-o', 'lib', 'src']

task 'test', 'Run tests', ->
	exec './node_modules/mocha/bin/mocha', ['--colors', '-R', 'spec']
	