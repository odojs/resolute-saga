logwatcher = require './logwatcher'
logwatcher = logwatcher 'docker:8500'

loglocker = require './loglocker'
loglocker = loglocker 'docker:8500'

loghelper = require './loghelper'

hub = require 'odo-hub/parallel'

logwatcher.watch 'sagas/saga1/',
  onlog: (instance) ->
    console.log instance
    console.log loghelper.interpret instance.log

# { "type": "seenmessage", "id": 1 }
# { "type": "seenmessage", "id": 2 }
# { "type": "seenmessage", "id": 3 }

# id = 1
# interval = setInterval ->
#   hub.emit 'message',
#     msgid: id,
#     value: 'awesome'
#   id++
# , 1000

# hub.every 'message', (e, cb) ->
#   instance = logwatcher.getinstance 'sagas/saga1/', 'exe1'
#   tryprocess = ->
#     loglocker.acquire 'sagas/saga1/', 'exe1', (success) ->
#     if success
#       console.log 'got lock'
#       loglocker.release 'sagas/saga1/', 'exe1'
#     else
#       console.log 'could not get lock'

#   cb()

process.on 'SIGINT', ->
  #clearInterval interval
  logwatcher.destroy()
  loglocker.destroy()