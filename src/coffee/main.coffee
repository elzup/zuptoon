
socket_url = 'http://localhost:3000'
socket = io.connect socket_url

socket.on 'pyon', (data) ->
  console.log(data)

socket.on 'count', (data) ->
  $count = $('#count')
  $count.text(data.count)
  console.log(data)

