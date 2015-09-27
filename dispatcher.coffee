async = require 'odo-async'
LOG = require './parser'

module.exports = (subscriptions, hub) ->
  _fin = no
  sagas = {}

  buildcontext = (url, sagakey, log) ->
    updates = LOG.blank()
    setTimeout: (key, timeout) ->
      updates.timeouts[key] = timeout
    clearTimeout: (key) ->
      updates.timeouttombstones[key] = yes
    setInterval: (key, anchor, count, unit, value) ->
      updates.intervals[key] =
        anchor: anchor
        count: count
        unit: unit
        value: value
    clearInterval: (key) ->
      updates.intervaltombstones[key] = yes
    clearMessage: (key) ->
      updates.messagetombstones[key] = yes
    set: (key, value) ->
      updates.data[key] = value
    get: (key) ->
      log.data[key]
    apply: ->
      for key, _ of updates.messagetombstones
        log.messagetombstones[key] = yes
      for key, _ of updates.timeouttombstones
        log.timeouttombstones[key] = yes
        delete log.timeouts[key]
      for key, _ of updates.intervaltombstones
        log.intervaltombstones[key] = yes
        delete log.intervals[key]
      for key, timeout of updates.timeouts
        delete log.timeouttombstones[key]
        log.timeouts[key] = timeout
      for key, interval of updates.intervals
        log.intervals[key] = interval

  res =
    register: (onmessage, url, module, cb) ->
      saga =
        subscriptions: {}
        module: module
      tasks = []
      module.saga
        map: (messagekey, fn) ->
          tasks.push (cb) ->
            return if saga.subscriptions[messagekey]?
            subscriptions.subscribe messagekey
            saga.subscriptions[messagekey] = yes
            saga.messagehandle = hub.every messagekey, (e, cb) ->
              sagakey = fn e
              onmessage url, sagakey, messagekey, e, cb
            console.log "#{url} subscribed to #{messagekey}"
            cb()
        ready: ->
          async.series tasks, ->
            console.log "configured #{url}"
            sagas[url] = saga
            cb() if cb?

    deregister: (url, cb) ->
      console.log "removing #{url}"
      if sagas[url]?
        for messagekey, _ of sagas[url].subscriptions
          subscriptions.unsubscribe messagekey
        sagas[url].messagehandle.off()
        delete sagas[url]
      cb() if cb?

    onmessage: (log, item, cb) ->
      if !sagas[item.url]?
        console.error "Saga #{item.url} not registered"
        return cb yes
      saga = sagas[item.url]
      context = buildcontext item.url, item.sagakey, log
      context.clearMessage item.message.id
      instance = saga.module.instance context
      fin = (success) ->
        return cb no if !success
        context.apply()
        cb yes
      if !instance[item.messagekey]?
        console.error "No handler for #{item.url}#{item.sagakey} message #{item.messagekey}"
        return fin yes
      instance[item.messagekey] item.message.data, fin

    ontimeout: (log, item, cb) ->
      if !sagas[item.url]?
        console.error "Saga #{item.url} not registered"
        return cb yes
      saga = sagas[item.url]
      context = buildcontext item.url, item.sagakey, log
      context.clearTimeout item.timeoutkey
      instance = saga.module.instance context
      fin = (success) ->
        return cb no if !success
        context.apply()
        cb yes
      if !instance[item.timeoutkey]?
        console.error "No handler for #{item.url}#{item.sagakey} timeout #{item.timeoutkey}"
        return fin yes
      instance[item.timeoutkey] item, fin

    oninterval: (log, item, cb) ->
      if !sagas[item.url]?
        console.error "Saga #{item.url} not registered"
        return cb yes
      saga = sagas[item.url]
      context = buildcontext item.url, item.sagakey, log
      context.setInterval(
        item.intervalkey,
        item.anchor,
        item.count,
        item.unit,
        item.value
      )
      instance = saga.module.instance context
      fin = (success) ->
        return cb no if !success
        context.apply()
        cb yes
      if !instance[item.intervalkey]?
        console.error "No handler for #{item.url}#{item.sagakey} interval #{item.intervalkey}"
        return fin yes
      instance[item.intervalkey] item, fin

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
