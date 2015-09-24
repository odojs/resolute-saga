loghelper = require './loghelper'
Queue = require 'seuss-backoff'

module.exports = (sagalog, sagalock, options) ->
  ontask = options.ontask

  queue = Queue onitem: (item, cb) ->
    message = (msg) -> "MESSAGE #{item.url}#{item.sagakey}.#{item.messagekey} #{item.message.msgid} #{msg}"

    instance = sagalog.getoutdated item.url, item.sagakey
    if err?
      console.log message 'UNABLE TO LOAD'
      return cb no

    log = instance?.log
    log ?= []
    interpreted = instance?.interpreted
    interpreted ?= loghelper.blankinterpretedlog()

    # if the message has already been seen then all good
    if interpreted.handledmessages[item.message.msgid]?
      console.log message 'ALREADY SEEN'
      return cb yes

    # Need to lock something separate to log?
    # So the lock doesn't need to know the contents?
    sagalock.acquire item.url, item.sagakey, (success) ->
      if !success
        console.log message 'COULD NOT LOCK'
        return cb no
      sagalog.get item.url, item.sagakey, (err, instance) ->
        if err?
          console.log message 'UNABLE TO COMPLETE READ'

        log = instance?.log
        log ?= []
        interpreted = instance?.interpreted
        interpreted ?= loghelper.blankinterpretedlog()
        alreadyseen = interpreted.handledmessages[item.message.msgid]?
        if alreadyseen
          console.log message 'ALREADY SEEN'

        if err? or alreadyseen
          return sagalock.release item.url, item.sagakey, ->
            cb no

        log.push
          type: 'handledmessage'
          id: item.message.msgid
        sagalog.set item.url, item.sagakey, log, (err) ->
          sagalock.release item.url, item.sagakey, (success) ->
            if !success or err?
              console.log message 'UNABLE TO COMPLETE WRITE'
              return cb no
            console.log message 'WRITTEN TO LOG'
            cb yes

  handle = sagalog.onlog (url, instance) ->
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
