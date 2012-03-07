(function() {
  var DEFAULTS, Stash, async, noop, redis, _,
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
      this.config = _.extend(DEFAULTS, config);
      this.redis = redis.createClient(this.config.port, this.config.host);
    }

    Stash.prototype.quit = function(force) {
      if (force == null) force = false;
      if (force) {
        return this.redis.end();
      } else {
        return this.redis.quit();
      }
    };

    Stash.prototype.get = function(key, callback) {
      var _this = this;
      return this.redis.get(key, function(err, data) {
        if (err != null) return callback(err);
        return callback(null, _this._unpack(data));
      });
    };

    Stash.prototype.set = function(key, value, callback) {
      if (callback == null) callback = noop;
      return this.redis.set(key, this._pack(value), callback);
    };

    Stash.prototype.inv = function() {
      var args, callback,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      return this._walk(_.flatten(args), function(err, graph) {
        return _this.redis.del(graph.nodes, function(err) {
          if (err != null) return callback(err);
          return callback(null, graph.nodes);
        });
      });
    };

    Stash.prototype.rem = function() {
      var args, callback, keys,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      keys = _.flatten(args);
      return this.inv(keys, function(err) {
        if (err != null) return callback(err);
        return async.forEach(keys, _.bind(_this.drem, _this), function(err) {
          if (err != null) return callback(err);
          return _this.redis.del(keys, function(err) {
            if (err != null) return callback(err);
            return callback(null, keys);
          });
        });
      });
    };

    Stash.prototype.dget = function() {
      var callback, getEdges, keys, _i,
        _this = this;
      keys = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), callback = arguments[_i++];
      keys = _.flatten(keys);
      getEdges = function(key, next) {
        return async.parallel({
          "in": function(done) {
            return _this.redis.smembers(_this._inkey(key), done);
          },
          out: function(done) {
            return _this.redis.smembers(_this._outkey(key), done);
          }
        }, next);
      };
      if (keys.length === 1) {
        return getEdges(keys[0], callback);
      } else {
        return async.map(keys, getEdges, function(err, results) {
          var reducer;
          if (err != null) return callback(err);
          reducer = function(deps, result, index) {
            deps[keys[index]] = result;
            return deps;
          };
          return callback(null, _.reduce(results, reducer, {}));
        });
      }
    };

    Stash.prototype.dset = function() {
      var args, callback, child, parents,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      child = args.shift();
      parents = _.flatten(args);
      return this.dget(child, function(err, deps) {
        if (err != null) return callback(err);
        return async.parallel({
          added: function(done) {
            return _this.dadd(child, _.difference(parents, deps["in"]), done);
          },
          removed: function(done) {
            return _this.drem(child, _.difference(deps["in"], parents), done);
          }
        }, callback);
      });
    };

    Stash.prototype.dadd = function() {
      var addEdges, args, callback, child, parents,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      child = args.shift();
      parents = _.flatten(args);
      addEdges = function(parent, next) {
        return async.parallel([
          function(done) {
            return _this.redis.sadd(_this._outkey(parent), child, done);
          }, function(done) {
            return _this.redis.sadd(_this._inkey(child), parent, done);
          }
        ], next);
      };
      return async.forEach(parents, addEdges, function(err) {
        if (err != null) return callback(err);
        return callback(null, parents);
      });
    };

    Stash.prototype.drem = function() {
      var args, callback, child, parents, removeEdges,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      callback = _.isFunction(_.last(args)) ? args.pop() : noop;
      child = args.shift();
      if (args.length > 0) {
        parents = _.flatten(args);
        removeEdges = function(parent, next) {
          return async.parallel([
            function(done) {
              return _this.redis.srem(_this._outkey(parent), child, done);
            }, function(done) {
              return _this.redis.srem(_this._inkey(child), parent, done);
            }
          ], next);
        };
        return async.forEach(parents, removeEdges, function(err) {
          if (err != null) return callback(err);
          return callback(null, parents);
        });
      } else {
        return this.dget(child, function(err, deps) {
          var removeEdge;
          if (err != null) return callback(err);
          parents = deps["in"];
          removeEdge = function(parent, next) {
            return _this.redis.srem(_this._outkey(parent), child, next);
          };
          return async.forEach(parents, removeEdge, function(err) {
            if (err != null) return callback(err);
            return _this.redis.del(_this._inkey(child), function(err) {
              if (err != null) return callback(err);
              return callback(null, parents);
            });
          });
        });
      }
    };

    Stash.prototype._walk = function(keys, callback) {
      var collect, graph, moreleft, remaining,
        _this = this;
      graph = {
        nodes: keys,
        edges: [],
        depth: 0
      };
      remaining = _.map(keys, this._outkey);
      moreleft = function() {
        return remaining.length > 0;
      };
      collect = function(next) {
        return _this.redis.sunion(remaining, function(err, deps) {
          graph.edges = _.union(graph.edges, remaining);
          graph.depth++;
          if (err == null) {
            graph.nodes = _.union(graph.nodes, deps);
            remaining = _.difference(_.map(deps, _this._outkey), graph.edges);
          }
          return next();
        });
      };
      return async.whilst(moreleft, collect, function(err) {
        if (err != null) return callback(err);
        return callback(null, graph);
      });
    };

    Stash.prototype._inkey = function(key) {
      return "stash:" + key + ":in";
    };

    Stash.prototype._outkey = function(key) {
      return "stash:" + key + ":out";
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
