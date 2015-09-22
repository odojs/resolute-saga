// Generated by CoffeeScript 1.9.2
var consul;

consul = require('consul-utils');

module.exports = function(httpAddr) {
  var locks, session;
  locks = {};
  session = consul.TTLSession(httpAddr);
  session.run({
    ondown: function() {
      return locks = {};
    }
  });
  return {
    acquire: function(url, key, contents, cb) {
      var lock, prefix;
      if (!session.isvalid()) {
        if (cb != null) {
          cb(false);
        }
        return;
      }
      prefix = "" + url + key;
      if (locks[prefix] != null) {
        if (cb != null) {
          cb(true);
        }
        return;
      }
      lock = consul.Lock(httpAddr, prefix);
      locks[prefix] = {
        url: url,
        key: key,
        lock: lock
      };
      return lock.acquire(session.id(), contents, cb);
    },
    release: function(url, key, contents, cb) {
      var prefix;
      prefix = "" + url + key;
      if (!session.isvalid() || (locks[prefix] == null)) {
        if (cb != null) {
          cb(true);
        }
        return;
      }
      return locks[prefix].lock.release(session.id(), contents, function(success) {
        delete locks[prefix];
        if (cb != null) {
          return cb(success);
        }
      });
    },
    destroy: function(cb) {
      return session.destroy(cb);
    }
  };
};
