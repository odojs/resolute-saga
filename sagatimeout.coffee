moment = require 'moment-timezone'
spanner = require 'timespanner'
chrono = require 'chronological'
moment = chrono spanner moment
loghelper = require './loghelper'

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
    for key, _ of instance.interpreted.clearedtimeouts
      continue if !timeouts[key]?
      timeouts[key].cancel()
      delete timeouts[key]
    for key, _ of instance.interpreted.handledtimeouts
      continue if !timeouts[key]?
      timeouts[key].cancel()
      delete timeouts[key]
    for key, timeout of instance.interpreted.timeouts
      continue if timeouts[key]?
      do (key, timeout) ->
        timeout = moment.utc timeout, 'YYYY-MM-DD[T]HH:mm:ssZ'
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
