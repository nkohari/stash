async  = require 'async'
redis  = require 'redis'
_      = require 'underscore'

noop     = ->
arrayify = (what) -> if _.isArray(what) then what else [what]

defaults =
	host:   'localhost'
	port:   6379
	prefix: 'stash'

class Stash
	
	constructor: (config) ->
		@config = _.extend defaults, config
		@redis  = redis.createClient @config.port, @config.host
	
	get: (key, callback) ->
		@redis.get key, callback
	
	set: (key, value, callback = noop) ->
		@redis.set key, @_pack(value), callback
	
	dep: (child, parents, callback = noop) ->
		add = (parent, next) =>
			@redis.sadd @_depkey(parent), child, next
		async.map arrayify(parents), add, callback
	
	# TODO: This is currently O(N) since it executes one SMEMBERS for each dependency
	# resolution. If instead we used SUNION to resolve multiple dependency pointers
	# at once, we could make it O(log N).
	inv: (key, callback = noop) ->
		invalid  = [key]
		queue    = [@_depkey(key)]
		moreleft = -> queue.length > 0
		collect  = (next) =>
			key = queue.pop()
			return next() unless key?
			@redis.smembers key, (err, deps) =>
				unless err?
					invalid = _.union invalid, deps
					queue   = _.union queue,   _.map deps, @_depkey
				next()
		async.whilst moreleft, collect, (err) =>
			@redis.del invalid, (err) ->
				callback(null, invalid)
	
	_depkey: (key)  -> "#{key}:deps"
	_pack:   (obj)  -> if _.isString(obj) then obj else JSON.stringify(obj)
	_unpack: (data) -> JSON.parse(data)
	
module.exports = Stash
