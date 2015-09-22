moment = require 'moment-timezone'
spanner = require 'timespanner'
chrono = require 'chronological'
moment = chrono spanner moment

logwatcher = require './logwatcher'
logwatcher = logwatcher 'docker:8500'

loglocker = require './loglocker'
loglocker = loglocker 'docker:8500'

sagatimeout = require './sagatimeout'
sagatimeout = sagatimeout logwatcher,
  ontimeout: (url, sagakey, timeoutkey) ->
    console.log "TIMEOUT #{url}#{sagakey}.#{timeoutkey}"

loghelper = require './loghelper'

hub = require 'odo-hub/parallel'
async = require 'odo-async'

logwatcher.watch 'sagas/saga1/'

# { "type": "handledmessage", "id": 1 }
# { "type": "handledmessage", "id": 2 }
# { "type": "handledmessage", "id": 3 }

id = 1
interval = setInterval ->
  hub.emit 'message', { msgid: id, value: 'awesome' }
  id++
, 1000

retrymessage = (e, cb) ->
  console.log "Trying #{e.msgid} again in 10 seconds"
  setTimeout ->
    trymessage e, cb
  , 10000

trymessage = (e, cb) ->
  instance = logwatcher.getinstance 'sagas/saga1/', 'exe1'
  log = instance?.log
  log ?= []

  # if the message has already been seen then all good
  interpreted = instance?.interpreted
  interpreted ?= loghelper.blankinterpretedlog()
  if interpreted.handledmessages[e.msgid]?
    console.log "Message #{e.msgid} already seen"
    return cb()

  loglocker.acquire 'sagas/saga1/', 'exe1', loghelper.stringify(log), (success) ->
    return retrymessage e, cb if !success
    log.push
      type: 'handledmessage'
      id: e.msgid
    loglocker.release 'sagas/saga1/', 'exe1', loghelper.stringify(log), (success) ->
      return retrymessage e, cb if !success
      console.log "#{e.msgid} written to log"
      cb()

hub.every 'message', trymessage

process.on 'SIGINT', ->
  clearInterval interval
  logwatcher.destroy()
  loglocker.destroy()
  sagatimeout.destroy()