moment = require 'moment-timezone'
chrono = require 'chronological'
moment = chrono moment
iso8601 = require './iso8601'

module.exports = (sagalog, options) ->
  timeoutsforsagas = {}

  ontimeout = options.ontimeout
  ontimeout ?= ->

  handle = sagalog.onlog (url, instance) ->
    if !timeoutsforsagas[url]?
      timeoutsforsagas[url] = {}
    timeoutsforsaga = timeoutsforsagas[url]
    if !timeoutsforsaga[instance.key]?
      timeoutsforsaga[instance.key] = {}
    timeouts = timeoutsforsaga[instance.key]
    for key, _ of instance.log.timeouttombstones
      continue if !timeouts[key]?
      timeouts[key].cancel()
      #console.log "#{url}#{instance.key} -timeout #{key}"
      delete timeouts[key]
    for key, timeout of instance.log.timeouts
      if timeouts[key]?
        timeouts[key].cancel()
        delete timeouts[key]
      do (key, timeout) ->
        timeouts[key] = timeout.timer (value) ->
          delete timeouts[key]
          ontimeout url, instance.key, key, value

  destroy: ->
    handle.off()
    for _, timeoutsforsaga of timeoutsforsagas
      for _, timeouts of timeoutsforsaga
        for _, timeout of timeouts
          timeout.cancel()
    timeoutsforsagas = {}
