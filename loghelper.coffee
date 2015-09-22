module.exports =
  parse: (value) ->
    value
      .split '\n'
      .filter (a) -> a isnt ''
      .map (a) -> JSON.parse a

  stringify: (log) ->
    log
      .map (a) -> JSON.stringify a
      .join '\n'

  interpret: (log) ->
    res =
      handledmessages: {}

      timeouts: {}
      handledtimeouts: {}
      clearedtimeouts: {}

      intervals: {}
      handledintervals: {}
      clearedintervals: {}

      other: []

    for item in log
      switch item.type
        when 'handledmessage'
          res.handledmessages[item.id] = yes
        when 'settimeout'
          res.timeouts[item.id] = item.timeout
        when 'handledtimeout'
          delete res.timeouts[item.id]
          res.handledtimeouts[item.id] = yes
        when 'cleartimeout'
          delete res.timeouts[item.id]
          res.clearedtimeouts[item.id] = yes
        when 'setinterval'
          res.timeouts[item.id] = item.interval
        when 'handledinterval'
          delete res.intervals[item.id]
          res.handledintervals[item.id] = yes
        when 'clearinterval'
          delete res.intervals[item.id]
          res.clearedintervals[item.id] = yes
        else
          res.other.push item

    res
