consul = require 'consul-utils'
loghelper = require './loghelper'

module.exports = (httpAddr) ->
  sagas = {}

  makewatch = (url) ->
    new consul.KV httpAddr, url, { recurse: yes }, (keys) ->
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
          isavailable: !key.Session?
        sagas[url].log[key.Key] = instance
        sagas[url].onlog instance

  res =
    watch: (url, options) ->
      return if sagas[url]?

      options ?= {}
      onlog = options.onlog
      onlog ?= ->

      sagas[url] =
        url: url
        onlog: onlog
        log: {}
        available: []

      sagas[url].watch = makewatch url, options

    unwatch: (url) ->
      return if !sagas[url]?
      sagas[url].watch.end()
      delete sagas[url]

    getinstance: (url, key) ->
      return null if !sagas[url]?
      sagas[url].log[key]

    destroy: (cb) ->
      res.unwatch url for url, _ of sagas
      cb() if cb?
