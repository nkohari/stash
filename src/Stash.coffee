async  = require 'async'
redis  = require 'redis'
_      = require 'underscore'

noop = () ->

DEFAULTS =
	host:   'localhost'
	port:   6379

class Stash
	
	constructor: (config) ->
		@config = _.extend DEFAULTS, config
		@redis  = redis.createClient @config.port, @config.host
	
	get: (key, callback) ->
		@redis.get @_nodekey(key), callback
	
	set: (key, value, callback = noop) ->
		@redis.set @_nodekey(key), @_pack(value), callback
	
	dep: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		child    = @_nodekey args.shift()
		parents  = _.map _.flatten(args), @_edgekey
		makeEdge = (parent, next) => @redis.sadd parent, child, next
		async.map parents, makeEdge, callback
	
	inv: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		@_graph _.flatten(args), (err, graph) =>
			@redis.del graph.nodes, (err) =>
				if err? then callback(err, null)
				else callback null, graph.nodes
	
	rem: (args...) ->
		callback = if _.isFunction _.last args then args.pop() else noop
		keys     = _.flatten args
		allkeys  = _.union _.map(keys, @_nodekey), _.map(keys, @_edgekey)
		@redis.del allkeys, (err) =>
			if err? then callback(err, null)
			else callback null, allkeys
	
	_graph: (keys, callback) ->
		nodes     = _.map keys, @_nodekey
		remaining = _.map keys, @_edgekey
		edges     = []
		moreleft  = -> remaining.length > 0
		collect   = (next) =>
			@redis.sunion remaining, (err, deps) =>
				edges = _.union edges, remaining
				unless err?
					nodes     = _.union nodes, deps
					nextgen   = _.map deps, @_edgekey
					remaining = _.difference nextgen, edges
				next()
		async.whilst moreleft, collect, (err) ->
			if err? then return callback(err, null)
			callback null, {nodes, edges}
	
	_nodekey:  (key)  => key
	_edgekey:  (key)  => "#{key}:deps"
	_pack:     (obj)  -> if _.isString(obj) then obj else JSON.stringify(obj)
	_unpack:   (data) -> JSON.parse(data)
	
module.exports = Stash
