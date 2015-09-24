async = require 'odo-async'

module.exports = (subscriptions, hub) ->
  _fin = no
  sagas = {}

  loadsaga = (saga) ->
    instancecontext =
      messages: {}
      timeouts: {}
      intervals: {}
      every: (messagekey, cb) ->

  res =
    register: (url, module, cb) ->
      sagacontext =
        subscriptions: {}
        module: module
      tasks = []
      module.saga
        map: (messagekey, fn) ->
          tasks.push (cb) ->
            return if sagacontext.subscriptions[messagekey]?
            subscriptions.subscribe messagekey
            sagacontext.subscriptions[messagekey] = yes
            console.log "#{url} subscribed to #{messagekey}"
            cb()
        ready: ->
          async.series tasks, ->
            console.log "configured #{url}"
            sagas[url] = sagacontext
            cb() if cb?

    deregister: (url, cb) ->
      console.log "removing #{url}"
      # unregister from events
      # close all locks
      # do more stuff
      if sagas[url]?
        for messagekey, _ of sagas[url].subscriptions
          subscriptions.unsubscribe messagekey
        delete sagas[url]
      cb() if cb?

    onmessage: (log, item, cb) ->
      log.messagetombstones[item.message.msgid] = yes
      cb yes
      # if !sagas[context.url]?
      #   return context.error 'Saga url not registered'
      # sagacontext = sagas[context.url]
      # result = []
      # instance = sagacontext.module.instance
      #   settimeout: (id, timeout) ->
      #     result.push
      #       type: 'timeout'
      #       id: id
      #       timeout: timeout.format 'YYYY-MM-DD[T]HH:mm:ssZ'
      #   setinterval: (id, anchor, count, unit, start) ->
      #     result.push
      #       type: 'interval'
      #       id: id
      #       anchor: anchor.format 'YYYY-MM-DD[T]HH:mm:ssZ'
      #       count: count
      #       unit: unit
      #       start: start
      #   setdata: (id, data) ->
      #     result.push
      #       type: 'data'
      #       id: id
      #       data: data
      #   getdata: (id) ->
      #     context.interpreted.data[id]
      # instance[messagekey] e, (err) ->
      #   return context.error err if err?
      #   context.result result

    ontimeout: (log, item, cb) ->
      delete log.timeouts[item.timeoutkey]
      log.timeouttombstones[item.timeoutkey] = yes
      cb yes

    oninterval: (log, item, cb) ->
      log.intervals[item.intervalkey].value = item.value
      cb yes

    end: (cb) ->
      if _fin
        cb() if cb?
        return
      tasks = []
      for url, _ of sagas
        do (url) ->
          tasks.push (cb) -> res.deregister url, cb
      async.series tasks, ->
        _fin = yes
        cb() if cb?
  res
