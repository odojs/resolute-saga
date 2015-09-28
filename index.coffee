sagalog = require './log'
sagalock = require './lock'
resolute = require 'resolute'
subscriptions = require 'resolute/subscriptions'
dispatcher = require './dispatcher'
coordinator = require './coordinator'
sagatimeout = require './timeout'
sagainterval = require './interval'

hub = require('odo-hub/hub') require('odo-hub/dispatch_parallel')()

# Connect components together to make a monster
sagalog = sagalog 'docker:8500'
sagalock = sagalock 'docker:8500'
bus = resolute
  bind: "tcp://127.0.0.1:#{process.argv[2]}"
  datadir: "./#{process.argv[2]}"
subscriptions = subscriptions bus
dispatcher = dispatcher subscriptions, bus.raw
coordinator = coordinator sagalog, sagalock,
  onmessage: dispatcher.onmessage
  ontimeout: dispatcher.ontimeout
  oninterval: dispatcher.oninterval
sagatimeout = sagatimeout coordinator,
  ontimeout: coordinator.ontimeout
sagainterval = sagainterval coordinator,
  oninterval: coordinator.oninterval

# Would get these from configuration somewhere
subscriptions.bind 'weather update', 'tcp://127.0.0.1:12346'

dispatcher.register coordinator.onmessage, 'sagas/saga1/', require './testsaga'
sagalog.watch 'sagas/saga1/'

# Exit in weird and wonderful ways
exittimeout = null
process.on 'SIGINT', ->
  close = ->
    clearTimeout exittimeout
    bus.close()
    coordinator.destroy()
    sagalog.destroy()
    sagalock.destroy()
  exit = ->
    close()
    process.exit 0
  exit() if exittimeout?
  exittimeout = setTimeout exit, 10000
  console.log 'Waiting for queues to empty.'
  console.log '(^C again to quit)'
  sagatimeout.destroy()
  sagainterval.destroy()
  dispatcher.end ->
    bus.drain ->
      bus.close()
      coordinator.drain ->
        close()