moment = require 'moment-timezone'
iso8601 = require './iso8601'

blank = ->
  data: {}
  timeouts: {}
  timeouttombstones: {}
  intervals: {}
  intervaltombstones: {}
  messagetombstones: {}

module.exports =
  blank: blank
  parse: (content) ->
    result = blank()
    for s, index in content.split '\n'
      s = s.trim()
      # skip empty ss
      continue if s is ''
      # skip comments
      continue if s[0] is '#'
      # expect parameters split by one or more spaces
      params = s.split ' '
      params.shift()
      params = params.filter (c) -> c isnt ''
      # messages start with m
      if s[0] is 'm'
        if params.length isnt 1
          console.log "Line #{index + 1}. Unknown message entry \"#{s}\""
          continue
        [key] = params
        result.messagetombstones[key] = yes
      # timeouts start with t
      else if s[0] is 't'
        if params.length is 3
          [key, timeout] = params
          result.timeouts[key] = moment.utc timeout, iso8601
        else if params.length is 2
          [key] = params
          result.timeouttombstones[key] = yes
        else
          console.log "Line #{index + 1}. Unknown timeout entry \"#{s}\""
          continue
      # intervals start with i
      else if s[0] is 'i'
        # interval is optional (will discover next closest)
        if params.length is 5
          [key, anchor, count, unit, interval] = params
          result.intervals[key] =
            anchor: moment.utc anchor, iso8601
            count: count
            unit: unit
            interval: interval
        else if params.length is 4
          [key, anchor, count, unit] = params
          result.intervals[key] =
            anchor: moment.utc anchor, iso8601
            count: count
            unit: unit
        else if params.length is 2
          [key] = params
          result.intervaltombstones[key] = yes
        else
          console.log "Line #{index + 1}. Unknown interval entry \"#{s}\""
          continue
      # data starts with d
      else if s[0] is 'd'
        if params.length is 0
          console.log "Line #{index + 1}. Unknown data entry \"#{s}\""
          continue
        [key] = params
        params = s.split ' '
        params.shift()
        params.shift()
        data = params.join ' '
        result.data[key] = JSON.parse data
      # nothing else in the log format (yet?)
      else
        console.log "Line #{index + 1}. Unknown log entry \"#{s}\""
    result

  stringify: (log) ->
    r = []
    r.push '# Data'
    for key, value of log.data
      r.push "data #{key} #{JSON.stringify value}"
    r.push ''
    r.push '# Timeouts'
    for key, timeout of log.timeouts
      r.push "timeout #{key} #{timeout.format iso8601} active"
    for key, _ of log.timeouttombstones
      r.push "timeout #{key} tombstone"
    r.push ''
    r.push '# Intervals'
    for key, interval of log.intervals
      if interval.interval?
        r.push "interval #{key} #{interval.anchor.format iso8601} #{interval.count} #{interval.unit} #{interval.interval}"
      else
        r.push "interval #{key} #{interval.anchor.format iso8601} #{interval.count} #{interval.unit}"
    for key, _ of log.intervaltombstones
      r.push "interval #{key} tombstone"
    r.push ''
    r.push '# Message IDs Seen'
    for key, _ of log.messagetombstones
      r.push "message #{key}"
    r.push ''
    r.join '\n'
