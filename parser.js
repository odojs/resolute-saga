// Generated by CoffeeScript 1.9.2
var blank, insanekey, iso8601, moment, sanekey, validKeys;

moment = require('moment-timezone');

iso8601 = require('./iso8601');

sanekey = function(key) {
  return key.replace(' ', '+');
};

insanekey = function(key) {
  return key.replace('+', ' ');
};

validKeys = /(\S|)+/;

blank = function() {
  return {
    data: {},
    timeouts: {},
    timeouttombstones: {},
    intervals: {},
    intervaltombstones: {},
    messagetombstones: {}
  };
};

module.exports = {
  blank: blank,
  isValidKey: function(key) {
    return key.match(validKeys) != null;
  },
  parse: function(content) {
    var anchor, count, data, i, index, key, len, params, ref, result, s, timeout, unit, value;
    result = blank();
    ref = content.split('\n');
    for (index = i = 0, len = ref.length; i < len; index = ++i) {
      s = ref[index];
      s = s.trim();
      if (s === '') {
        continue;
      }
      if (s[0] === '#') {
        continue;
      }
      params = s.split(' ');
      params.shift();
      params = params.filter(function(c) {
        return c !== '';
      });
      if (s[0] === 'm') {
        if (params.length !== 1) {
          console.log("Line " + (index + 1) + ". Unknown message entry \"" + s + "\"");
          continue;
        }
        key = params[0];
        key = insanekey(key);
        result.messagetombstones[key] = true;
      } else if (s[0] === 't') {
        if (params.length === 2) {
          key = params[0], timeout = params[1];
          key = insanekey(key);
          result.timeouts[key] = moment.utc(timeout, iso8601);
          delete result.timeouttombstones[key];
        } else if (params.length === 1) {
          key = params[0];
          key = insanekey(key);
          result.timeouttombstones[key] = true;
          delete result.timeouts[key];
        } else {
          console.log("Line " + (index + 1) + ". Unknown timeout entry \"" + s + "\"");
          continue;
        }
      } else if (s[0] === 'i') {
        if (params.length === 5) {
          key = params[0], anchor = params[1], count = params[2], unit = params[3], value = params[4];
          key = insanekey(key);
          result.intervals[key] = {
            anchor: moment.utc(anchor, iso8601),
            count: parseInt(count),
            unit: unit,
            value: parseInt(value)
          };
        } else if (params.length === 4) {
          key = params[0], anchor = params[1], count = params[2], unit = params[3];
          key = insanekey(key);
          result.intervals[key] = {
            anchor: moment.utc(anchor, iso8601),
            count: parseInt(count),
            unit: unit
          };
        } else if (params.length === 1) {
          key = params[0];
          key = insanekey(key);
          result.intervaltombstones[key] = true;
        } else {
          console.log("Line " + (index + 1) + ". Unknown interval entry \"" + s + "\"");
          continue;
        }
      } else if (s[0] === 'd') {
        if (params.length === 0) {
          console.log("Line " + (index + 1) + ". Unknown data entry \"" + s + "\"");
          continue;
        }
        key = params[0];
        key = insanekey(key);
        params = s.split(' ');
        params.shift();
        params.shift();
        data = params.join(' ');
        result.data[key] = JSON.parse(data);
      } else {
        console.log("Line " + (index + 1) + ". Unknown log entry \"" + s + "\"");
      }
    }
    return result;
  },
  stringify: function(log) {
    var _, interval, key, r, ref, ref1, ref2, ref3, ref4, ref5, timeout, value;
    r = [];
    r.push('# Data');
    ref = log.data;
    for (key in ref) {
      value = ref[key];
      r.push("data " + (sanekey(key)) + " " + (JSON.stringify(value)));
    }
    r.push('');
    r.push('# Timeouts');
    ref1 = log.timeouts;
    for (key in ref1) {
      timeout = ref1[key];
      r.push("timeout " + (sanekey(key)) + " " + (timeout.utc().format(iso8601)));
    }
    ref2 = log.timeouttombstones;
    for (key in ref2) {
      _ = ref2[key];
      r.push("timeout " + (sanekey(key)));
    }
    r.push('');
    r.push('# Intervals');
    ref3 = log.intervals;
    for (key in ref3) {
      interval = ref3[key];
      if (interval.value != null) {
        r.push("interval " + (sanekey(key)) + " " + (interval.anchor.utc().format(iso8601)) + " " + interval.count + " " + interval.unit + " " + interval.value);
      } else {
        r.push("interval " + (sanekey(key)) + " " + (interval.anchor.utc().format(iso8601)) + " " + interval.count + " " + interval.unit);
      }
    }
    ref4 = log.intervaltombstones;
    for (key in ref4) {
      _ = ref4[key];
      r.push("interval " + (sanekey(key)));
    }
    r.push('');
    r.push('# Message IDs Seen');
    ref5 = log.messagetombstones;
    for (key in ref5) {
      _ = ref5[key];
      r.push("message " + (sanekey(key)));
    }
    r.push('');
    return r.join('\n');
  }
};
