consul = require 'consul-utils'

module.exports = (httpAddr) ->
  _fin = no

  locks = {}

  session = consul.TTLSession httpAddr
  session.run
    ondown: -> locks = {}

  acquire: (url, key, contents, cb) ->
    prefix = "#{url}#{key}"
    if !session.isvalid() or locks[prefix]?
      cb no if cb?
      return
    lock = consul.Lock httpAddr, prefix
    locks[prefix] =
      url: url
      key: key
      lock: lock
    #console.log "Locking #{prefix}"
    lock.acquire session.id(), contents, (success) ->
      delete locks[prefix] if !success
      cb success if cb?

  release: (url, key, contents, cb) ->
    prefix = "#{url}#{key}"
    if !session.isvalid() or !locks[prefix]?
      cb yes if cb?
      return
    #console.log "Releasing #{prefix}"
    locks[prefix].lock.release session.id(), contents, (success) ->
      delete locks[prefix]
      cb success if cb?

  destroy: (cb) ->
    return if _fin
    _fin = yes
    session.destroy cb