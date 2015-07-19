app = require('../app')

###*
# Socket io
###

skio = (server, io) ->
  server.listen app.get('port'), ->
    console.log('listening !!')

  io.on 'connection', (socket) ->
    person_count = socket.client.conn.server.clientsCount
    io.emit 'count', count: person_count

    socket.on 'shake', (data) ->
      console.log 'shake!' + socket.id
      data.id = socket.id
      io.emit 'shake', data
      return

    socket.on 'move', (data) ->
      console.log 'move!' + data
      data.id = socket.id
      io.emit 'move', data
      return

    socket.on 'new', (data) ->
      console.log 'new : ' + socket.io
      socket.join(data.room)
      data.id = socket.id
      if data.room == 'user'
        io.to('top').emit 'createuser', data
      return

    socket.on 'leave', (data) ->
      console.log 'leave : ' + socket.id
      data.id = socket.id
      io.emit 'leave', data
      return

    socket.on 'disconnect', ->
      # var person_count = socket.client.conn.server.clientsCount;
      console.log 'exit : ' + socket.id
      data = id: socket.id
      io.emit 'removeuser', data
      return
    return

module.exports = skio
