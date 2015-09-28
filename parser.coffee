moment = require 'moment-timezone'
iso8601 = require './iso8601'

sanekey = (key) -> key.replace ' ', '+'
insanekey = (key) -> key.replace '+', ' '
validKeys = ///(\S| )+///

blank = ->
  data: {}
  timeouts: {}
  timeouttombstones: {}
  intervals: {}
  intervaltombstones: {}
  messagetombstones: {}

module.exports =
  blank: blank
  isValidKey: (key) ->
    key.match(validKeys)?
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
        key = insanekey key
        result.messagetombstones[key] = yes
      # timeouts start with t
      else if s[0] is 't'
        if params.length is 2
          [key, timeout] = params
          key = insanekey key
          result.timeouts[key] = moment.utc timeout, iso8601
          delete result.timeouttombstones[key]
        else if params.length is 1
          [key] = params
          key = insanekey key
          result.timeouttombstones[key] = yes
          delete result.timeouts[key]
        else
          console.log "Line #{index + 1}. Unknown timeout entry \"#{s}\""
          continue
      # intervals start with i
      else if s[0] is 'i'
        # value is optional (will discover next closest)
        if params.length is 5
          [key, anchor, count, unit, value] = params
          key = insanekey key
          result.intervals[key] =
            anchor: moment.utc anchor, iso8601
            count: parseInt count
            unit: unit
            value: parseInt value
        else if params.length is 4
          [key, anchor, count, unit] = params
          key = insanekey key
          result.intervals[key] =
            anchor: moment.utc anchor, iso8601
            count: parseInt count
            unit: unit
        else if params.length is 1
          [key] = params
          key = insanekey key
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
        key = insanekey key
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
      r.push "data #{sanekey key} #{JSON.stringify value}"
    r.push ''
    r.push '# Timeouts'
    for key, timeout of log.timeouts
      r.push "timeout #{sanekey key} #{timeout.utc().format iso8601}"
    for key, _ of log.timeouttombstones
      r.push "timeout #{sanekey key}"
    r.push ''
    r.push '# Intervals'
    for key, interval of log.intervals
      if interval.value?
        r.push "interval #{sanekey key} #{interval.anchor.utc().format iso8601} #{interval.count} #{interval.unit} #{interval.value}"
      else
        r.push "interval #{sanekey key} #{interval.anchor.utc().format iso8601} #{interval.count} #{interval.unit}"
    for key, _ of log.intervaltombstones
      r.push "interval #{sanekey key}"
    r.push ''
    r.push '# Message IDs Seen'
    for key, _ of log.messagetombstones
      r.push "message #{sanekey key}"
    r.push ''
    r.join '\n'
