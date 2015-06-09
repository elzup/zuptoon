$ ->
  # enchant game
  console.log('load shake controller')
  enchant()
  game = new Core(320, 320)
  game.preload('images/pad.png')
  game.fps = 20;

  game.onload = ->
    pointer = new Sprite(32, 32)
    pointer.image = game.assets['images/pad.png']
    pointer.scale(0.1)

    pointer.tl.moveTo(100, 100)

    game.rootScene.addEventListener Event.ENTER_FRAME, () ->
      dx = 0
      dy = 0

      if game.input.up || game.input.down || game.input.left || game.input.right
        if game.input.up
          dy -= 1
        if game.input.down
          dy += 1
        if game.input.left
          dx -= 1
        if game.input.right
          dx += 1
        if dx != 0 && dy != 0
          dx *= 0.7
          dy *= 0.7
        emit_move(dx, dy)

    pad = new Pad()
    pad.scale(3.0, 3.0)
    pad.moveTo(game.width / 2 - pad.width / 2, game.height / 2 - pad.height / 2)

    game.rootScene.addChild(pointer)
    game.rootScene.addChild(pad)

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url
  socket.emit 'new'

  # スマホのシェイクイベントを取得
  emit_shake = ->
    socket.emit 'shake'

  emit_move = (dx, dy) ->
    console.log(dx, dy)
    socket.emit 'move',
      dx: dx
      dy: dy

  # 新規ユーザ作成
  $(@).gShake -> emit_shake()
