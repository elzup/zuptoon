###
# Module dependencies.
###

debug = require('debug')('pyonpyon:server')
app = require('../app')
http = require('http')
server = http.createServer(app)
skio = require('../socket/skio')

###
# Normalize a port into a number, string, or false.
###

normalizePort = (val) ->
  `var port`
  port = parseInt(val, 10)
  if isNaN(port)
# named pipe
    return val
  if port >= 0
# port number
    return port
  false

###
# Get port from environment and store in Express.
###

port = normalizePort(process.env.PORT or '8080')
app.set 'port', port

###
# Event listener for HTTP server "error" event.
###

onError = (error) ->
  if error.syscall != 'listen'
    throw error
  bind = if typeof port == 'string' then 'Pipe ' + port else 'Port ' + port
  # handle specific listen errors with friendly messages
  switch error.code
    when 'EACCES'
      console.error bind + ' requires elevated privileges'
      process.exit 1
    when 'EADDRINUSE'
      console.error bind + ' is already in use'
      process.exit 1
    else
      throw error
  return

###
# Event listener for HTTP server "listening" event.
###

onListening = ->
  addr = server.address()
  bind = if typeof addr == 'string' then 'pipe ' + addr else 'port ' + addr.port
  debug 'Listening on ' + bind
  return


###
# Create HTTP server.
###

server.listen port
server.on 'error', onError
server.on 'listening', onListening

io = require('socket.io').listen(server)
skio(server, io)

