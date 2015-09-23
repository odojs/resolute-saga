consul = require 'consul-utils'
loghelper = require './loghelper'

module.exports = (httpAddr) ->
  _fin = no

  sagas = {}

  _listeners = []

  readkv = (url, keys) ->
    if !sagas[url]?
      console.error "#{url} already deleted, how come I'm still watching?"
      return
    keys = keys
      .filter (k) -> k.Key isnt url
      .map (d) ->
        d.Key = d.Key.substr url.length
        d.Value ?= ''
        d
    for key in keys
      log = loghelper.parse key.Value
      instance =
        key: key.Key
        log: log
        interpreted: loghelper.interpret log
        isavailable: !key.Session?
      sagas[url].log[key.Key] = instance
      listener url, instance for listener in _listeners

  makewatch = (url) ->
    new consul.KV httpAddr, url, { recurse: yes }, (keys) ->
      readkv url, keys

  res =
    watch: (url) ->
      return if sagas[url]?

      sagas[url] =
        url: url
        log: {}
        available: []

      sagas[url].watch = makewatch url

    unwatch: (url) ->
      return if !sagas[url]?
      sagas[url].watch.end()
      delete sagas[url]

    getinstance: (url, key) ->
      return null if !sagas[url]?
      sagas[url].log[key]

    getinstancenow: (url, key, cb) ->
      consul.GetKV httpAddr, "#{url}#{key}", (err, keys) ->
        return cb err if err?
        readkv url, keys
        if !sagas[url].log[key]?
          return cb null,
            key: key
            log: loghelper.blanklog()
            interpreted: loghelper.blankinterpretedlog()
            isavailable: yes
        cb null, sagas[url].log[key]

    onlog: (cb) ->
      _listeners.push cb
      off: ->
        index = _listeners.indexOf cb
        if index isnt -1
          _listeners.splice index, 1

    destroy: (cb) ->
      return if _fin
      _fin = yes
      res.unwatch url for url, _ of sagas
      cb() if cb?
