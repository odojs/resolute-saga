consul = require 'consul-utils'
loghelper = require './loghelper'

strendswith = (str, suffix) ->
  str.indexOf(suffix, str.length - suffix.length) isnt -1

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
      .filter (k) -> strendswith k.Key, '.log'
      .map (d) ->
        d.Key = d.Key.substr url.length
        d.Key = d.Key.substr 0, d.Key.length - 4
        d.Value ?= ''
        d
    for key in keys
      log = loghelper.parse key.Value
      instance =
        log: log
        interpreted: loghelper.interpret log
      sagas[url].log[key.Key] = instance
      listener url, instance for listener in _listeners

  makewatch = (url) ->
    new consul.KV httpAddr, url, { recurse: yes }, (keys) ->
      readkv url, keys

  getblanklog = (key) ->
    log: loghelper.blanklog()
    interpreted: loghelper.blankinterpretedlog()

  res =
    watch: (url) ->
      return if sagas[url]?

      sagas[url] =
        log: {}

      sagas[url].watch = makewatch url

    unwatch: (url) ->
      return if !sagas[url]?
      sagas[url].watch.end()
      delete sagas[url]

    getoutdated: (url, key) ->
      return getblanklog key if !sagas[url]?
      return getblanklog key if !sagas[url].log[key]?
      sagas[url].log[key]

    get: (url, key, cb) ->
      consul.GetKV httpAddr, "#{url}#{key}.log", (err, keys) ->
        return cb err if err?
        readkv url, keys
        if !sagas[url].log[key]?
          return cb null, getblanklog key
        cb null, sagas[url].log[key]

    set: (url, key, content, cb) ->
      content = loghelper.stringify content
      consul.SetKV httpAddr, "#{url}#{key}.log", content, (err) ->
        return cb err if err?
        sagas[url].log[key] = loghelper.parse content
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
