
socket_url = 'http://192.168.1.50'
socket = io.connect socket_url

socket.on 'pyon', (data) ->
  console.log(data)

socket.on 'count', (data) ->
  $count = $('#count')
  $count.text(data.count)
  console.log(data)
