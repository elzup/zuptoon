$ ->
  # enchant game
  console.log('load main controller')
  enchant()
  game = new Core(320, 320)
  game.preload('/images/apad.png')
  game.fps = 20;

  # action(shot)と判定するが中央からの距離
  RADIUS_ACTION = game.width * 0.4

  game.onload = ->

    # NOTE: game.rootScene#size game.root#size 違い
    # とりあえず画像のサイズ
    bg = new Sprite(100, 100)
    bg.scale(game.width / 100, game.width / 100)
    bg.moveTo(game.width / 2 - bg.width / 2, game.height / 2 - bg.height / 2)
    bg.image = game.assets['/images/apad.png']
    game.rootScene.addChild(bg)

    is_touch = false
    ex = null
    ey = null

    game.rootScene.addEventListener Event.ENTER_FRAME, () ->
      if is_touch
        dx = ex - game.width / 2
        dy = ey - game.height / 2
        va = ElzupUtils.vec_maguniture(dx, dy)
        is_action = va > RADIUS_ACTION
        emit_move(dx / va, dy / va, is_action)

    game.rootScene.addEventListener Event.TOUCH_START, (e) ->
      ex = e.x
      ey = e.y
      is_touch = true
    game.rootScene.addEventListener Event.TOUCH_END, (e) ->
      is_touch = false

    game.rootScene.addEventListener Event.TOUCH_MOVE, (e) ->
      ex = e.x
      ey = e.y

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url
  socket.emit 'new'

  # スマホのシェイクイベントを取得
  emit_shake = ->
    socket.emit 'shake',
      act: 'shot'

  emit_move = (dx, dy, is_action=false) ->
    console.log(dx, dy, is_action)
    # shake controller は no shot
    is_action = false
    socket.emit 'move',
      dx: dx
      dy: dy
      act: is_action


  # 新規ユーザ作成
  $(@).gShake -> emit_shake()
