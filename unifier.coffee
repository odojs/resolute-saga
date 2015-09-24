Queue = require 'seuss-backoff'
iso8601 = require './iso8601'

module.exports = (sagalog, sagalock, options) ->
  ontask = options.ontask

  open = (item, message, cb) ->
    sagalock.acquire item.url, item.sagakey, (success) ->
      if !success
        console.log message 'COULD NOT LOCK'
        return cb no, null
      sagalog.get item.url, item.sagakey, (err, log) ->
        if err?
          console.log message 'UNABLE TO COMPLETE READ'
          return sagalock.release item.url, item.sagakey, -> cb no, null
        cb yes, log

  commit = (item, log, message, cb) ->
    sagalog.set item.url, item.sagakey, log, (err) ->
      sagalock.release item.url, item.sagakey, (success) ->
        if err?
          if success
            console.log message 'UNABLE TO COMPLETE WRITE, RELEASED LOCK ANYWAY'
          else
            console.log message 'UNABLE TO COMPLETE WRITE, UNABLE TO RELEASE LOCK'
          return cb no
        if success
          console.log message 'WRITTEN TO LOG'
        else
          console.log message 'WRITTEN TO LOG, UNABLE TO RELEASE LOCK'
        return cb yes

  queue = Queue onitem: (item, cb) ->
    if item.type is 'message'
      message = (msg) -> "#{item.url}#{item.sagakey} MESSAGE #{item.messagekey}##{item.message.msgid} #{msg}"
      alreadyseenin = (log) ->
        if log.messagetombstones[item.message.msgid]?
          console.log message 'ALREADY SEEN'
          return yes
        no

      log = sagalog.getoutdated item.url, item.sagakey
      return cb yes if alreadyseenin log

      open item, message, (success, log) ->
        return cb no if !success

        if alreadyseenin log
          return sagalock.release item.url, item.sagakey, -> cb yes

        log.messagetombstones[item.message.msgid] = yes

        commit item, log, message, cb
    else if item.type is 'timeout'
      message = (msg) -> "#{item.url}#{item.sagakey} TIMEOUT #{item.timeoutkey}@#{item.value.format iso8601} #{msg}"
      alreadyseenin = (log) ->
        if log.timeouttombstones[item.timeoutkey]?
          console.log message 'TOMBSTONED'
          return yes
        no

      log = sagalog.getoutdated item.url, item.sagakey
      return cb yes if alreadyseenin log

      open item, message, (success, log) ->
        return cb no if !success

        if alreadyseenin log
          return sagalock.release item.url, item.sagakey, -> cb yes

        delete log.timeouts[item.timeoutkey]
        log.timeouttombstones[item.timeoutkey] = yes

        commit item, log, message, cb
    else if item.type is 'interval'
      message = (msg) -> "#{item.url}#{item.sagakey} INTERVAL #{item.intervalkey}@#{item.value.format iso8601}*#{item.count} #{msg}"
      alreadyseenin = (log) ->
        if log.intervaltombstones[item.intervalkey]?
          console.log message 'TOMBSTONED'
          return yes
        if log.intervals[item.intervalkey].value >= item.count
          console.log message 'ALREADY SEEN'
          return yes
        no
      isfutureevent = (log) ->
        if log.intervals[item.intervalkey].value + 1 < item.count
          console.log message 'FUTURE EVENT'
          return yes
        no

      log = sagalog.getoutdated item.url, item.sagakey
      return cb yes if alreadyseenin log
      return cb no if isfutureevent log

      open item, message, (success, log) ->
        return cb no if !success

        if alreadyseenin log
          return sagalock.release item.url, item.sagakey, -> cb yes
        if isfutureevent log
          return sagalock.release item.url, item.sagakey, -> cb no

        log.intervals[item.intervalkey].value = item.count

        commit item, log, message, cb
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
  oninterval: (url, sagakey, intervalkey, count, value) ->
    queue.enqueue
      type: 'interval'
      url: url
      sagakey: sagakey
      intervalkey: intervalkey
      count: count
      value: value
  drain: (cb) ->
    queue.drain cb
  destroy: ->
    queue.destroy()
