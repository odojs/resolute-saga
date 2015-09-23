loghelper = require './loghelper'
Queue = require 'seuss-backoff'

# TODO: optimisation to collect all saga and instance messages together?
module.exports = (logwatcher, loglocker, options) ->
  ontask = options.ontask

  queue = Queue onitem: (item, cb) ->
    instance = logwatcher.getinstancenow item.url, item.sagakey, (err, instance) ->
      if err?
        console.log "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} UNABLE TO LOAD"
        return cb no

      log = instance?.log
      log ?= []

      # if the message has already been seen then all good
      interpreted = instance?.interpreted
      interpreted ?= loghelper.blankinterpretedlog()
      if interpreted.handledmessages[item.message.msgid]?
        console.log "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} ALREADY SEEN"
        return cb yes

      # Need to lock something separate to log?
      # So the lock doesn't need to know the contents?
      loglocker.acquire item.url, item.sagakey, loghelper.stringify(log), (success) ->
        if !success
          console.log "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} COULD NOT LOCK"
          return cb no
        log.push
          type: 'handledmessage'
          id: item.message.msgid
        loglocker.release item.url, item.sagakey, loghelper.stringify(log), (success) ->
          if !success
            console.log "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} UNABLE TO COMPLETE WRITE"
            return cb no
          console.log "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} WRITTEN TO LOG"
          cb yes

  handle = logwatcher.onlog (url, instance) ->
    # purge items in queue if found in log

  onmessage: (url, sagakey, messagekey, e, cb) ->
    #console.log "MESSAGE #{url}#{sagakey}.#{messagekey} #{e.msgid}"
    queue.enqueue
      url: url
      sagakey: sagakey
      messagekey: messagekey
      message: e
      cb: cb

  ontimeout: (url, sagakey, timeoutkey, value) ->
    console.log "TIMEOUT #{url}#{sagakey}.#{timeoutkey}"
  oninterval: (url, sagakey, intervalkey, count, value) ->
    console.log "INTERVAL #{url}#{sagakey}.#{intervalkey}"
  drain: (cb) ->
    queue.drain cb
  destroy: ->
    queue.destroy()
    handle.off()
