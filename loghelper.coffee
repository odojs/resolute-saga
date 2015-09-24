module.exports =
  result =
    blanklog: ->
      []

    blankinterpretedlog: ->
      handledmessages: {}

      timeouts: {}
      handledtimeouts: {}
      clearedtimeouts: {}

      intervals: {}
      handledintervals: {}
      clearedintervals: {}

      data: {}

      other: []

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
      res = result.blankinterpretedlog()

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
            res.intervals[item.id] =
              anchor: item.anchor
              count: item.count
              unit: item.unit
              interval: item.interval
          when 'handledinterval'
            res.intervals[item.id].interval = item.interval
            res.handledintervals[item.id] = item.interval
          when 'clearinterval'
            delete res.intervals[item.id]
            res.clearedintervals[item.id] = yes
          when 'setdata'
            res.data[item.id] = item.data
          else
            res.other.push item

      res
