moment = require 'moment-timezone'
iso8601 = 'YYYY-MM-DD[T]HH:mm:ss[Z]'

module.exports =
  parse: (content) ->
    result =
      data: {}
      timeouts: {}
      timeouttombstones: {}
      intervals: {}
      intervaltombstones: {}
      messagetombstones: {}
    for s, index in content.split '\n'
      s = s.trim()
      # skip empty ss
      continue if s is ''
      # skip comments
      i = 0
      if s[0] is '#'
        continue
      params = s.split ' '
      params.shift()
      params = params.filter (c) -> c isnt ''
      if s[0] is 'm'
        if params.length isnt 1
          console.log "Line #{index + 1}. Unknown message entry \"#{s}\""
          continue
        [key] = params
        result.messagetombstones[key] = yes
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
      else if s[0] is 'i'
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
