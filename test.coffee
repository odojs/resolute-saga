consul = require 'consul-utils'
moment = require 'moment-timezone'
spanner = require 'timespanner'
chrono = require 'chronological'
moment = chrono spanner moment
async = require 'odo-async'



resolute = require 'resolute'
bus = resolute
  bind: 'tcp://127.0.0.1:12345'
  datadir: './12345'

Subscriptions = require 'resolute/subscriptionmanager'

subscriptions = Subscriptions bus,
  'weather update': [
    'tcp://127.0.0.1:12346'
  ]

Dispatcher = (worker, bus, subscriptions) ->
  sagas = {}

  res =
    register: (saganame, saga, cb) ->
      sagacontext =
        subscriptions: []
        saga: saga
      tasks = []
      saga.configuresaga
        map: (key, fn) ->
          tasks.push (cb) ->
            subscriptions.subscribe key, ->
              sagacontext.subscriptions.push key
              console.log "#{saganame} subscribed to #{key}"
              cb()
        ready: ->
          async.parallel tasks, ->
            console.log "#{saganame} configured"
            sagas[saganame] = sagacontext
            cb() if cb?

    deregister: (saganame, cb) ->
      console.log "removing #{saganame}"
      # unregister from events
      # close all locks
      # do more stuff
      tasks = []
      for key in sagas[saganame].subscriptions
        do (key) ->
          tasks.push (cb) -> subscriptions.unsubscribe key, cb
      async.parallel tasks, ->
        delete sagas[saganame]
        cb() if cb?

    end: (cb) ->
      tasks = []
      for key, _ of sagas
        do (key) ->
          tasks.push (cb) -> res.deregister key, cb
      async.parallel tasks, ->
        cb() if cb?
  res

dispatcher = Dispatcher worker, bus, subscriptions
dispatcher.register 'saga1', require './testsaga'

process.on 'SIGINT', ->
  dispatcher.end ->
    worker.destroy ->
      bus.close()



# lock = consul.Lock httpAddr, 'test_lock'

# haslock = no
# trylock = ->
#   return if haslock
#   lock.acquire session.id(), (success) ->
#     if success
#       console.log 'received lock, happy'
#       haslock = yes
#       cancelwaitingforlock()
#       return
#     waitforlock()

# getlock = null
# waitforlock = ->
#   return if watchlock?
#   getlock = consul.GetKV 'docker:8500', 'test_lock', (err, results) ->
#     console.log results
# cancellock = ->
#   haslock = no
# cancelwaitingforlock = ->
#   if getlock?
#     getlock.abort()
#     getlock = null