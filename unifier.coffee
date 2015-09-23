loghelper = require './loghelper'

module.exports = (logwatcher, loglocker, options) ->
  ontask = options.ontask

  queued = {}

  handle = logwatcher.onlog (url, instance) ->
    # purge items
    return if !queued[url]?
    return if !queued[url][instance.key]?

    # queued[url] = {} if !queued[url]?
    # queued[url][sagakey] = [] if !queued[url][sagakey]?
    # queued[url][sagakey].push ->
    #   trymessage e, cb

  onmessage: (url, sagakey, messagekey, e, cb) ->
    console.log "MESSAGE #{url}#{sagakey}.#{messagekey} #{e.msgid}"

    retrymessage = (e, cb) ->
      console.log "Trying #{messagekey} #{e.msgid} again in 1 seconds"
      setTimeout ->
        trymessage e, cb
      , 1000

    trymessage = (e, cb) ->
      instance = logwatcher.getinstance url, sagakey
      log = instance?.log
      log ?= []

      # if the message has already been seen then all good
      interpreted = instance?.interpreted
      interpreted ?= loghelper.blankinterpretedlog()
      if interpreted.handledmessages[e.msgid]?
        console.log "Message #{e.msgid} already seen"
        return cb()

      loglocker.acquire url, sagakey, loghelper.stringify(log), (success) ->
        return retrymessage e, cb if !success
        log.push
          type: 'handledmessage'
          id: e.msgid
        loglocker.release url, sagakey, loghelper.stringify(log), (success) ->
          return retrymessage e, cb if !success
          console.log "#{e.msgid} written to log"
          cb()

    trymessage e, cb

  ontimeout: (url, sagakey, timeoutkey, value) ->
    console.log "TIMEOUT #{url}#{sagakey}.#{timeoutkey}"
  oninterval: (url, sagakey, intervalkey, count, value) ->
    console.log "INTERVAL #{url}#{sagakey}.#{intervalkey}"
  destroy: ->
    handle.off()