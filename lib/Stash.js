(function() {
  var DEFAULTS, Stash, async, noop, redis, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = Array.prototype.slice;

  async = require('async');

  redis = require('redis');

  _ = require('underscore');

  noop = function() {};

  DEFAULTS = {
    host: 'localhost',
    port: 6379
  };

  Stash = (function() {

    function Stash(config) {
      this._edgekey = __bind(this._edgekey, this);
      this._nodekey = __bind(this._nodekey, this);      this.config = _.extend(DEFAULTS, config);
      this.redis = redis.createClient(this.config.port, this.config.host);
    }

    Stash.prototype.get = function(key, callback) {
      return this.redis.get(this._nodekey(key), callback);
    };

    Stash.prototype.set = function(key, value, callback) {
      if (callback == null) callback = noop;
      return this.redis.set(this._nodekey(key), this._pack(value), callback);
    };

    Stash.prototype.dep = function() {
      var args, callback, child, makeEdge, parents,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      child = this._nodekey(args.shift());
      parents = _.map(_.flatten(args), this._edgekey);
      makeEdge = function(parent, next) {
        return _this.redis.sadd(parent, child, next);
      };
      return async.map(parents, makeEdge, callback);
    };

    Stash.prototype.inv = function() {
      var args, callback,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      return this._graph(_.flatten(args), function(err, graph) {
        return _this.redis.del(graph.nodes, function(err) {
          if (err != null) {
            return callback(err, null);
          } else {
            return callback(null, graph.nodes);
          }
        });
      });
    };

    Stash.prototype.rem = function() {
      var allkeys, args, callback, keys,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      keys = _.flatten(args);
      allkeys = _.union(_.map(keys, this._nodekey), _.map(keys, this._edgekey));
      return this.redis.del(allkeys, function(err) {
        if (err != null) {
          return callback(err, null);
        } else {
          return callback(null, allkeys);
        }
      });
    };

    Stash.prototype._graph = function(keys, callback) {
      var collect, edges, moreleft, nodes, remaining,
        _this = this;
      nodes = _.map(keys, this._nodekey);
      remaining = _.map(keys, this._edgekey);
      edges = [];
      moreleft = function() {
        return remaining.length > 0;
      };
      collect = function(next) {
        return _this.redis.sunion(remaining, function(err, deps) {
          var nextgen;
          edges = _.union(edges, remaining);
          if (err == null) {
            nodes = _.union(nodes, deps);
            nextgen = _.map(deps, _this._edgekey);
            remaining = _.difference(nextgen, edges);
          }
          return next();
        });
      };
      return async.whilst(moreleft, collect, function(err) {
        if (err != null) return callback(err, null);
        return callback(null, {
          nodes: nodes,
          edges: edges
        });
      });
    };

    Stash.prototype._nodekey = function(key) {
      return key;
    };

    Stash.prototype._edgekey = function(key) {
      return "" + key + ":deps";
    };

    Stash.prototype._pack = function(obj) {
      if (_.isString(obj)) {
        return obj;
      } else {
        return JSON.stringify(obj);
      }
    };

    Stash.prototype._unpack = function(data) {
      return JSON.parse(data);
    };

    return Stash;

  })();

  module.exports = Stash;

}).call(this);
