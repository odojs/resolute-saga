// Generated by CoffeeScript 1.9.2
var Queue, iso8601;

Queue = require('seuss-backoff');

iso8601 = require('./iso8601');

module.exports = function(sagalog, sagalock, options) {
  var _listeners, _pendingupdates, _updateswilldrain, commit, handle, oninterval, onmessage, ontimeout, queue, read;
  onmessage = options.onmessage, ontimeout = options.ontimeout, oninterval = options.oninterval;
  _listeners = [];
  read = function(item, message, cb) {
    return sagalock.acquire(item.url, item.sagakey, function(success) {
      if (!success) {
        return cb(false, null);
      }
      return sagalog.get(item.url, item.sagakey, function(err, log) {
        if (err != null) {
          return sagalock.release(item.url, item.sagakey, function(success) {
            if (!success) {
              console.error(message('read failed, release incomplete'));
            }
            return cb(false, null);
          });
        }
        return cb(true, log);
      });
    });
  };
  commit = function(item, log, message, cb) {
    return sagalog.set(item.url, item.sagakey, log, function(err) {
      return sagalock.release(item.url, item.sagakey, function(success) {
        if (err != null) {
          if (success) {
            console.error(message('commit failed, release complete'));
          } else {
            console.error(message('commit failed, releae incomplete'));
          }
          return cb(false);
        }
        if (!success) {
          console.error(message('commit complete, release incomplete'));
        }
        return cb(true);
      });
    });
  };
  _pendingupdates = {};
  _updateswilldrain = false;
  handle = sagalog.onlog(function(url, instance) {
    if (_pendingupdates[url] == null) {
      _pendingupdates[url] = {};
    }
    _pendingupdates[url][instance.key] = instance;
    if (!_updateswilldrain) {
      _updateswilldrain = true;
      return queue.drain(function() {
        var _, i, len, listener, sagaupdates;
        for (url in _pendingupdates) {
          sagaupdates = _pendingupdates[url];
          for (_ in sagaupdates) {
            instance = sagaupdates[_];
            for (i = 0, len = _listeners.length; i < len; i++) {
              listener = _listeners[i];
              listener(url, instance);
            }
          }
        }
        _pendingupdates = {};
        return _updateswilldrain = false;
      });
    }
  });
  queue = Queue({
    onitem: function(item, cb) {
      var alreadyseenin, intervalisinlog, isfutureevent, log, message, timeoutisinlog;
      if (item.type === 'message') {
        message = function(msg) {
          return "" + item.url + item.sagakey + " " + item.messagekey + "#" + item.message.id + " " + msg;
        };
        alreadyseenin = function(log) {
          if (log.messagetombstones[item.message.id] != null) {
            return true;
          }
          return false;
        };
        log = sagalog.getoutdated(item.url, item.sagakey);
        if (alreadyseenin(log)) {
          return cb(true);
        }
        return read(item, message, function(success, log) {
          if (!success) {
            return cb(false);
          }
          if (alreadyseenin(log)) {
            return sagalock.release(item.url, item.sagakey, function() {
              return cb(true);
            });
          }
          return onmessage(log, item, function(success) {
            if (success) {
              return commit(item, log, message, cb);
            } else {
              return sagalock.release(item.url, item.sagakey, function() {
                return cb(true);
              });
            }
          });
        });
      } else if (item.type === 'timeout') {
        message = function(msg) {
          return "" + item.url + item.sagakey + " " + item.timeoutkey + "@" + (item.value.format(iso8601)) + " " + msg;
        };
        alreadyseenin = function(log) {
          if (log.timeouttombstones[item.timeoutkey] != null) {
            return true;
          }
          return false;
        };
        timeoutisinlog = function(log) {
          if (log.timeouts[item.timeoutkey] == null) {
            return false;
          }
          if (log.timeouts[item.timeoutkey].isSame(item.value)) {
            return true;
          }
          return false;
        };
        log = sagalog.getoutdated(item.url, item.sagakey);
        if (!timeoutisinlog(log) || alreadyseenin(log)) {
          return cb(true);
        }
        return read(item, message, function(success, log) {
          if (!success) {
            return cb(false);
          }
          if (!timeoutisinlog(log) || alreadyseenin(log)) {
            return sagalock.release(item.url, item.sagakey, function() {
              return cb(true);
            });
          }
          return ontimeout(log, item, function(success) {
            if (success) {
              return commit(item, log, message, cb);
            } else {
              return sagalock.release(item.url, item.sagakey, function() {
                return cb(true);
              });
            }
          });
        });
      } else if (item.type === 'interval') {
        message = function(msg) {
          return "" + item.url + item.sagakey + " " + item.intervalkey + "@" + (item.anchor.format(iso8601)) + " " + item.count + item.unit + "*" + item.value + " " + msg;
        };
        alreadyseenin = function(log) {
          if (log.intervaltombstones[item.intervalkey] != null) {
            return true;
          }
          if (log.intervals[item.intervalkey] == null) {
            return true;
          }
          if (log.intervals[item.intervalkey].value >= item.value) {
            return true;
          }
          return false;
        };
        isfutureevent = function(log) {
          if (log.intervals[item.intervalkey].value + 1 < item.value) {
            console.error(message('future event'));
            return true;
          }
          return false;
        };
        intervalisinlog = function(log) {
          var loginterval;
          if (log.intervals[item.intervalkey] == null) {
            return false;
          }
          loginterval = log.intervals[item.intervalkey];
          if (loginterval.anchor.isSame(item.anchor) && loginterval.count === item.count && loginterval.unit === item.unit) {
            return true;
          }
          return false;
        };
        log = sagalog.getoutdated(item.url, item.sagakey);
        if (!intervalisinlog(log) || alreadyseenin(log)) {
          return cb(true);
        }
        if (isfutureevent(log)) {
          return cb(false);
        }
        return read(item, message, function(success, log) {
          if (!success) {
            return cb(false);
          }
          if (!intervalisinlog(log) || alreadyseenin(log)) {
            return sagalock.release(item.url, item.sagakey, function() {
              return cb(true);
            });
          }
          if (isfutureevent(log)) {
            return sagalock.release(item.url, item.sagakey, function() {
              return cb(false);
            });
          }
          return oninterval(log, item, function(success) {
            if (success) {
              return commit(item, log, message, cb);
            } else {
              return sagalock.release(item.url, item.sagakey, function() {
                return cb(true);
              });
            }
          });
        });
      } else {
        console.log("Unknown task " + item.type + ". Ignoring...");
        return cb(true);
      }
    }
  });
  return {
    onmessage: function(url, sagakey, messagekey, e, cb) {
      return queue.enqueue({
        type: 'message',
        url: url,
        sagakey: sagakey,
        messagekey: messagekey,
        message: e,
        cb: cb
      });
    },
    ontimeout: function(url, sagakey, timeoutkey, value) {
      return queue.enqueue({
        type: 'timeout',
        url: url,
        sagakey: sagakey,
        timeoutkey: timeoutkey,
        value: value
      });
    },
    oninterval: function(url, sagakey, intervalkey, anchor, count, unit, value, time) {
      return queue.enqueue({
        type: 'interval',
        url: url,
        sagakey: sagakey,
        intervalkey: intervalkey,
        anchor: anchor,
        count: count,
        unit: unit,
        value: value,
        time: time
      });
    },
    onlog: function(cb) {
      _listeners.push(cb);
      return {
        off: function() {
          var index;
          index = _listeners.indexOf(cb);
          if (index !== -1) {
            return _listeners.splice(index, 1);
          }
        }
      };
    },
    drain: function(cb) {
      return queue.drain(cb);
    },
    destroy: function() {
      handle.off();
      return queue.destroy();
    }
  };
};
