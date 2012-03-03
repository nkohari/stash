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
		add = (parent, next) => @redis.sadd @_depkey(parent), child, next
		if _.isArray(parents)
			async.map parents, add, callback
		else
			add(parents, callback)
	
	inv: (key, callback = noop) ->
		invalid   = [key]
		processed = []
		queue     = [@_depkey(key)]
		moreleft  = -> queue.length > 0
		collect   = (next) =>
			@redis.sunion queue, (err, deps) =>
				processed = _.union processed, queue
				unless err?
					invalid = _.union invalid, deps
					nextgen = _.map deps, @_depkey
					queue   = _.difference nextgen, processed
				next()
		async.whilst moreleft, collect, (err) =>
			@redis.del invalid, (err) ->
				callback(null, invalid)
	
	_depkey: (key)  -> "#{key}:deps"
	_pack:   (obj)  -> if _.isString(obj) then obj else JSON.stringify(obj)
	_unpack: (data) -> JSON.parse(data)
	
module.exports = Stash
