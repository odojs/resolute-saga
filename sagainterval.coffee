moment = require 'moment-timezone'
spanner = require 'timespanner'
chrono = require 'chronological'
moment = chrono spanner moment
loghelper = require './loghelper'

module.exports = (logwatcher, options) ->
  intervalsforsagas = {}

  oninterval = options.oninterval
  oninterval ?= ->

  handle = logwatcher.onlog (url, instance) ->
    if !intervalsforsagas[url]?
      intervalsforsagas[url] = {}
    intervalsforsaga = intervalsforsagas[url]
    if !intervalsforsaga[instance.key]?
      intervalsforsaga[instance.key] = {}
    intervals = intervalsforsaga[instance.key]
    for key, _ of instance.interpreted.clearedintervals
      continue if !intervals[key]?
      intervals[key].cancel()
      delete intervals[key]
    for key, _ of instance.interpreted.handledintervals
      continue if !intervals[key]?
      intervals[key].cancel()
      delete intervals[key]
    for key, interval of instance.interpreted.intervals
      if intervals[key]?
        intervals[key].end()
        delete intervals[key]
      do (key, interval) ->
        start = interval.start
        start++ if start?
        timer = moment
          .utc(interval.anchor, 'YYYY-MM-DD[T]HH:mm:ssZ')
          .every(interval.count, interval.unit)
        intervals[key] = timer.timer start, (count, value) ->
          oninterval url, instance.key, key, count, value

  destroy: ->
    handle.off()
    for _, intervalsforsaga of intervalsforsagas
      for _, intervals of intervalsforsaga
        for _, interval of intervals
          interval.end()
    intervalsforsagas = {}
