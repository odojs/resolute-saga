Queue = require 'seuss-backoff'
iso8601 = require './iso8601'

module.exports = (sagalog, sagalock, options) ->
  { onmessage, ontimeout, oninterval } = options
  _listeners = []

  read = (item, message, cb) ->
    sagalock.acquire item.url, item.sagakey, (success) ->
      return cb no, null if !success
      sagalog.get item.url, item.sagakey, (err, log) ->
        if err?
          return sagalock.release item.url, item.sagakey, (success) ->
            if !success
              console.error message 'read failed, release incomplete'
            cb no, null
        cb yes, log

  commit = (item, log, message, cb) ->
    sagalog.set item.url, item.sagakey, log, (err) ->
      sagalock.release item.url, item.sagakey, (success) ->
        if err?
          if success
            console.error message 'commit failed, release complete'
          else
            console.error message 'commit failed, releae incomplete'
          return cb no
        if !success
          console.error message 'commit complete, release incomplete'
        cb yes

  # Debounce updates while chewing through a backlog
  # This is essential for intervals
  _pendingupdates = {}
  _updateswilldrain = no
  handle = sagalog.onlog (url, instance) ->
    _pendingupdates[url] = {} if !_pendingupdates[url]?
    _pendingupdates[url][instance.key] = instance
    if !_updateswilldrain
      _updateswilldrain = yes
      queue.drain ->
        for url, sagaupdates of _pendingupdates
          for _, instance of sagaupdates
            for listener in _listeners
              listener url, instance
        _pendingupdates = {}
        _updateswilldrain = no

  queue = Queue onitem: (item, cb) ->
    if item.type is 'message'
      message = (msg) -> "#{item.url}#{item.sagakey} #{item.messagekey}##{item.message.id} #{msg}"
      alreadyseenin = (log) ->
        return yes if log.messagetombstones[item.message.id]?
        no

      log = sagalog.getoutdated item.url, item.sagakey
      return cb yes if alreadyseenin log

      read item, message, (success, log) ->
        return cb no if !success

        if alreadyseenin log
          return sagalock.release item.url, item.sagakey, -> cb yes

        onmessage log, item, (success) ->
          if success
            commit item, log, message, cb
          else
            sagalock.release item.url, item.sagakey, -> cb yes
    else if item.type is 'timeout'
      message = (msg) -> "#{item.url}#{item.sagakey} #{item.timeoutkey}@#{item.value.format iso8601} #{msg}"
      alreadyseenin = (log) ->
        return yes if log.timeouttombstones[item.timeoutkey]?
        no
      timeoutisinlog = (log) ->
        return no if !log.timeouts[item.timeoutkey]?
        return yes if log.timeouts[item.timeoutkey].isSame item.value
        no

      log = sagalog.getoutdated item.url, item.sagakey
      if !timeoutisinlog(log) or alreadyseenin(log)
        return cb yes

      read item, message, (success, log) ->
        return cb no if !success

        if !timeoutisinlog(log) or alreadyseenin(log)
          return sagalock.release item.url, item.sagakey, -> cb yes

        ontimeout log, item, (success) ->
          if success
            commit item, log, message, cb
          else
            sagalock.release item.url, item.sagakey, -> cb yes
    else if item.type is 'interval'
      message = (msg) -> "#{item.url}#{item.sagakey} #{item.intervalkey}@#{item.anchor.format iso8601} #{item.count}#{item.unit}*#{item.value} #{msg}"
      alreadyseenin = (log) ->
        return yes if log.intervaltombstones[item.intervalkey]?
        return yes if !log.intervals[item.intervalkey]?
        return yes if log.intervals[item.intervalkey].value >= item.value
        no
      isfutureevent = (log) ->
        if log.intervals[item.intervalkey].value + 1 < item.value
          console.error message 'future event'
          return yes
        no
      intervalisinlog = (log) ->
        return no if !log.intervals[item.intervalkey]?
        loginterval = log.intervals[item.intervalkey]
        if loginterval.anchor.isSame(item.anchor) and loginterval.count is item.count and loginterval.unit is item.unit
          return yes
        no

      log = sagalog.getoutdated item.url, item.sagakey
      return cb yes if !intervalisinlog(log) or alreadyseenin(log)
      return cb no if isfutureevent log

      read item, message, (success, log) ->
        return cb no if !success

        if !intervalisinlog(log) or alreadyseenin(log)
          return sagalock.release item.url, item.sagakey, -> cb yes
        if isfutureevent log
          return sagalock.release item.url, item.sagakey, -> cb no

        oninterval log, item, (success) ->
          if success
            commit item, log, message, cb
          else
            sagalock.release item.url, item.sagakey, -> cb yes
    else
      console.log "Unknown task #{item.type}. Ignoring..."
      cb yes

  onmessage: (url, sagakey, messagekey, e, cb) ->
    queue.enqueue
      type: 'message'
      url: url
      sagakey: sagakey
      messagekey: messagekey
      message: e
      cb: cb
  ontimeout: (url, sagakey, timeoutkey, value) ->
    queue.enqueue
      type: 'timeout'
      url: url
      sagakey: sagakey
      timeoutkey: timeoutkey
      value: value
  oninterval: (url, sagakey, intervalkey, anchor, count, unit, value, time) ->
    queue.enqueue
      type: 'interval'
      url: url
      sagakey: sagakey
      intervalkey: intervalkey
      anchor: anchor
      count: count
      unit: unit
      value: value
      time: time
  onlog: (cb) ->
    _listeners.push cb
    off: ->
      index = _listeners.indexOf cb
      if index isnt -1
        _listeners.splice index, 1
  drain: (cb) ->
    queue.drain cb
  destroy: ->
    handle.off()
    queue.destroy()
