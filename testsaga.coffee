moment = require 'moment-timezone'
chrono = require 'chronological'
moment = chrono moment




module.exports =
  saga: (context) ->
    #context.map 'weather update', (e) -> 'daemon'

    context.ready()

  instance: (context) ->
    'weather update': (e, cb) ->
      cb 'Not implemented'
      # context.settimeout 'too long between updates', moment().add 5, 'seconds'
      # console.log e
      # cb()

    'too long between updates': (e, cb) ->
      cb 'Not implemented'
      # console.log 'It has been too long between updates, haha'
      # cb()



# moment = require 'moment-timezone'
# spanner = require 'timespanner'
# chrono = require 'chronological'
# moment = chrono spanner moment




# module.exports =
#   configuresaga: (context) ->
#     context.map 'gfs downloaded', (e) -> e.cycle
#     context.map 'ww3 completed', (e) -> e.cycle
#     context.ready()

#   oninstanceloaded: (context) ->
#     context.every 'gfs downloaded', (e, cb) ->
#       context.publish 'start ww3 model', { cycle: e.cycle }, ->
#         context.settimeout 'ww3 taken 2 hours', moment().add(2, 'h')
#         cb()

#     context.every 'ww3 taken 2 hours', (e, cb) ->
#       console.log 'email TOM'
#       cb()

#     context.every 'ww3 completed', (e, cb) ->
#       context.cleartimeout 'ww3 taken 2 hours'
#       cb()

#     context.ready()



# class ConfigureWW3Saga:
#   def __init__(self, context):
#     context.map("gfs downloaded", self.mapgfs)
#     context.map("ww3 completed", self.mapww3complete)
#     context.mapclass(WW3Saga)
#     context.every("gfs downloaded", WW3Saga.gfsdownloaded)
#     context.every("ww3 completed", WW3Saga.ww3completed)
#     context.every("ww3 taken 2 hours", WW3Saga.ww3taken2hours)

#   def mapgfs(self, e):
#     return e.cycle

#   def mapww3complete(self, e):
#     return e.cycle

# class WW3Saga:
#   def __init__(self, context):
#     self.context = context

#   def gfsdownloaded(self, e):
#     self.context.publish("start ww3 model", { "cycle": e.cycle })
#     self.context.settimeout("ww3 taken 2 hours", new Date().add(2, 'h'))

#   def ww3completed(self, e):
#     self.context.cleartimeout("ww3 taken 2 hours")

#   def ww3taken2hours(self, e):
#     print('email TOM')