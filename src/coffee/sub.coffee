$ ->
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  socket.on 'pyon', (data) ->
    console.log(data)

  sc = 0
  # スマホのシェイクイベントを取得

  emit_shake = ->
    sc += 1
    console.log sc
    socket.emit 'shake',
      id: 1
    $shake = $('#shake')
    $shake.text(sc)

  $(@).gShake -> emit_shake()

  $('#shake-button').click ->
    emit_shake()
