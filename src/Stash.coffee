async  = require 'async'
redis  = require 'redis'
_      = require 'underscore'

noop = () ->

DEFAULTS =
	host: 'localhost'
	port: 6379

class Stash
	
	constructor: (config) ->
		@config = _.extend DEFAULTS, config
		@redis  = redis.createClient @config.port, @config.host
	
	quit: (force = false) ->
		if force then @redis.end()
		else @redis.quit()
	
	get: (key, callback) ->
		@redis.get @_nodekey(key), (err, data) =>
			if err? then callback(err)
			else callback null, @_unpack(data)
	
	set: (key, value, callback = noop) ->
		@redis.set @_nodekey(key), @_pack(value), callback
	
	dep: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		child    = args.shift()
		parents  = _.flatten(args)
		# NOTE: This could be improved to set multiple values for SADD, but that requires
		# Redis 2.4, and the in-memory computation probably isn't faster than parallelizing.
		addEdges = (parent, next) =>
			async.parallel [
				(done) => @redis.sadd @_outkey(parent), @_nodekey(child), done
				(done) => @redis.sadd @_inkey(child), @_nodekey(parent), done
			], next
		async.forEach parents, addEdges, callback
	
	inv: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		@_graph _.flatten(args), (err, graph) =>
			@redis.del graph.nodes, (err) =>
				if err? then callback(err, null)
				else callback null, graph.nodes
	
	rem: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		keys     = _.flatten args
		allkeys  = _.union _.map(keys, @_nodekey), _.map(keys, @_inkey), _.map(keys, @_outkey)
		@redis.del allkeys, (err) =>
			if err? then callback(err, null)
			else callback null, allkeys
	
	_graph: (keys, callback) ->
		graph =
			nodes: _.map keys, @_nodekey
			edges: []
			depth: 0
		remaining = _.map keys, @_outkey
		moreleft  = -> remaining.length > 0
		collect   = (next) =>
			@redis.sunion remaining, (err, deps) =>
				graph.edges = _.union graph.edges, remaining
				graph.depth++
				unless err?
					graph.nodes = _.union graph.nodes, deps
					remaining   = _.difference _.map(deps, @_outkey), graph.edges
				next()
		async.whilst moreleft, collect, (err) ->
			if err? then return callback(err)
			callback(null, graph)
	
	_nodekey:  (key)  -> key
	_inkey:    (key)  -> "#{key}:in"
	_outkey:   (key)  -> "#{key}:out"
	_pack:     (obj)  -> if _.isString(obj) then obj else JSON.stringify(obj)
	_unpack:   (data) -> JSON.parse(data)
	
module.exports = Stash
