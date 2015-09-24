moment = require 'moment-timezone'
chrono = require 'chronological'
moment = chrono moment
iso8601 = require './iso8601'

module.exports = (logwatcher, options) ->
  timeoutsforsagas = {}

  ontimeout = options.ontimeout
  ontimeout ?= ->

  handle = logwatcher.onlog (url, instance) ->
    if !timeoutsforsagas[url]?
      timeoutsforsagas[url] = {}
    timeoutsforsaga = timeoutsforsagas[url]
    if !timeoutsforsaga[instance.key]?
      timeoutsforsaga[instance.key] = {}
    timeouts = timeoutsforsaga[instance.key]
    for key, _ of instance.log.timeouttombstones
      continue if !timeouts[key]?
      timeouts[key].cancel()
      delete timeouts[key]
    for key, timeout of instance.log.timeouts
      continue if timeouts[key]?
      do (key, timeout) ->
        timeout = moment.utc timeout, iso8601
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
