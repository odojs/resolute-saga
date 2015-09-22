consul = require 'consul-utils'

module.exports = (httpAddr) ->
  locks = {}

  session = consul.TTLSession httpAddr
  session.run
    ondown: -> locks = {}

  acquire: (url, key, contents, cb) ->
    if !session.isvalid()
      cb no if cb?
      return
    prefix = "#{url}#{key}"
    if locks[prefix]?
      cb yes if cb?
      return
    lock = consul.Lock httpAddr, prefix
    locks[prefix] =
      url: url
      key: key
      lock: lock
    lock.acquire session.id(), contents, cb

  release: (url, key, contents, cb) ->
    prefix = "#{url}#{key}"
    if !session.isvalid() or !locks[prefix]?
      cb yes if cb?
      return
    locks[prefix].lock.release session.id(), contents, (success) ->
      delete locks[prefix]
      cb success if cb?

  destroy: (cb) ->
    session.destroy cb