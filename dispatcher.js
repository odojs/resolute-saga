// Generated by CoffeeScript 1.9.2
var async;

async = require('odo-async');

module.exports = function(subscriptions, hub) {
  var loadsaga, res, sagas;
  sagas = {};
  loadsaga = function(saga) {
    var instancecontext;
    return instancecontext = {
      messages: {},
      timeouts: {},
      intervals: {},
      every: function(messagekey, cb) {}
    };
  };
  res = {
    register: function(url, module, cb) {
      var sagacontext, tasks;
      sagacontext = {
        subscriptions: {},
        module: module
      };
      tasks = [];
      return module.saga({
        map: function(messagekey, fn) {
          return tasks.push(function(cb) {
            if (sagacontext.subscriptions[messagekey] != null) {
              return;
            }
            subscriptions.subscribe(messagekey);
            sagacontext.subscriptions[messagekey] = true;
            console.log(url + " subscribed to " + messagekey);
            return cb();
          });
        },
        ready: function() {
          return async.series(tasks, function() {
            console.log(url + " configured");
            sagas[url] = sagacontext;
            if (cb != null) {
              return cb();
            }
          });
        }
      });
    },
    deregister: function(url, cb) {
      var _, messagekey, ref;
      console.log("removing " + url);
      ref = sagas[url].subscriptions;
      for (messagekey in ref) {
        _ = ref[messagekey];
        subscriptions.unsubscribe(messagekey);
      }
      delete sagas[url];
      if (cb != null) {
        return cb();
      }
    },
    ontask: function(context, messagekey, e, cb) {
      var instance, result, sagacontext;
      if (sagas[context.url] == null) {
        return context.error('Saga url not registered');
      }
      sagacontext = sagas[context.url];
      result = [];
      instance = sagacontext.module.instance({
        settimeout: function(id, timeout) {
          return result.push({
            type: 'timeout',
            id: id,
            timeout: timeout.format('YYYY-MM-DD[T]HH:mm:ssZ')
          });
        },
        setinterval: function(id, anchor, count, unit, start) {
          return result.push({
            type: 'interval',
            id: id,
            anchor: anchor.format('YYYY-MM-DD[T]HH:mm:ssZ'),
            count: count,
            unit: unit,
            start: start
          });
        },
        setdata: function(id, data) {
          return result.push({
            type: 'data',
            id: id,
            data: data
          });
        },
        getdata: function(id) {
          return context.interpreted.data[id];
        }
      });
      return instance[messagekey](e, function(err) {
        if (err != null) {
          return context.error(err);
        }
        return context.result(result);
      });
    },
    end: function(cb) {
      var _, fn1, tasks, url;
      tasks = [];
      fn1 = function(url) {
        return tasks.push(function(cb) {
          return res.deregister(url, cb);
        });
      };
      for (url in sagas) {
        _ = sagas[url];
        fn1(url);
      }
      return async.series(tasks, function() {
        if (cb != null) {
          return cb();
        }
      });
    }
  };
  return res;
};
