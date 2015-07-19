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

    socket.on 'shake', ->
      console.log 'shake!' + socket.id
      io.to('top').emit 'shake', id: socket.id
      return

    socket.on 'move', (data) ->
      console.log 'move!' + socket.id
      data.id = socket.id
      io.emit 'move', data
      return

    socket.on 'new', (data) ->
      console.log 'new : ' + socket.id
      socket.join(data.room)
      data.id = socket.id
      if data.room == 'user'
        io.to('top').emit 'createuser', data
      return

    socket.on 'disconnect', ->
      # var person_count = socket.client.conn.server.clientsCount;
      console.log 'exit : ' + socket.id
      data = id: socket.id
      io.emit 'removeuser', data
      return
    return

module.exports = skio
