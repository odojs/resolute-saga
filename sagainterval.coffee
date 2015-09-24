moment = require 'moment-timezone'
chrono = require 'chronological'
moment = chrono moment
iso8601 = require './iso8601'

module.exports = (sagalog, options) ->
  intervalsforsagas = {}

  oninterval = options.oninterval
  oninterval ?= ->

  handle = sagalog.onlog (url, instance) ->
    if !intervalsforsagas[url]?
      intervalsforsagas[url] = {}
    intervalsforsaga = intervalsforsagas[url]
    if !intervalsforsaga[instance.key]?
      intervalsforsaga[instance.key] = {}
    intervals = intervalsforsaga[instance.key]
    for key, _ of instance.log.intervaltombstones
      continue if !intervals[key]?
      intervals[key].end()
      delete intervals[key]
    for key, interval of instance.log.intervals
      if intervals[key]?
        intervals[key].end()
        delete intervals[key]
      do (key, interval) ->
        value = interval.value
        value++ if value?
        timer = interval.anchor.every interval.count, interval.unit
        intervals[key] = timer.timer value, (value, count) ->
          oninterval url, instance.key, key, count, value

  destroy: ->
    handle.off()
    for _, intervalsforsaga of intervalsforsagas
      for _, intervals of intervalsforsaga
        for _, interval of intervals
          interval.end()
    intervalsforsagas = {}
