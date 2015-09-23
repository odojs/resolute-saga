logwatcher = require './logwatcher'
loglocker = require './loglocker'
loghelper = require './loghelper'
resolute = require 'resolute'
subscriptions = require 'resolute/subscriptions'
dispatcher = require './dispatcher'
unifier = require './unifier'
sagatimeout = require './sagatimeout'
sagainterval = require './sagainterval'

hub = require('odo-hub/hub') require('odo-hub/dispatch_parallel')()

# Connect components together to make a monster
logwatcher = logwatcher 'docker:8500'
loglocker = loglocker 'docker:8500'
sagatimeout = sagatimeout logwatcher, ontimeout: unifier.ontimeout
sagainterval = sagainterval logwatcher, oninterval: unifier.oninterval
bus = resolute bind: 'tcp://127.0.0.1:12345', datadir: './12345'
subscriptions = subscriptions bus
dispatcher = dispatcher subscriptions, hub
unifier = unifier logwatcher, loglocker, ontask: dispatcher.ontask

# Would get these from configuration somewhere
subscriptions.bind 'weather update', 'tcp://127.0.0.1:12346'
dispatcher.register 'sagas/saga1/', require './testsaga'
logwatcher.watch 'sagas/saga1/'

# This would be something the dispatcher sets up
hub.every 'message', (e, cb) ->
  unifier.onmessage 'sagas/saga1/', 'exe1', 'message', e, cb

# These messages would normally come from an external location
async = require 'odo-async'
async.delay ->
  hub.emit 'message', { msgid: 1, value: 'awesome' }
  hub.emit 'message', { msgid: 2, value: 'awesome' }

# Exit in weird and wonderful ways
exittimeout = null
process.on 'SIGINT', ->
  close = ->
    clearTimeout exittimeout
    unifier.destroy()
    bus.close()
    logwatcher.destroy()
    loglocker.destroy()
    sagatimeout.destroy()
    sagainterval.destroy()
  exit = ->
    close()
    process.exit 0
  exit() if exittimeout?
  exittimeout = setTimeout exit, 10000
  console.log 'Waiting for queues to empty.'
  console.log '(^C again to quit)'
  dispatcher.end ->
    bus.drain close