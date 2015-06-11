$ ->
  # enchant game
  console.log('load main controller')
  enchant()
  game = new Core(320, 320)
  game.preload('/images/apad.png')
  game.fps = 60

  RADIUS_ACTION = 160 * 0.4

  # action(shot)と判定するが中央からの距離
  RADIUS_ACTION = game.width * 0.4

  game.onload = ->

    # NOTE: game.rootScene#size game.root#size 違い
    # とりあえず画像のサイズ
    bg = new Sprite(100, 100)
    bg.scale(game.width / 200, game.width / 200)
    bg.moveTo(game.width / 2 - bg.width / 2, game.height / 2 - bg.height / 2)
    bg.image = game.assets['/images/apad.png']
    game.rootScene.addChild(bg)

    is_touch = false
    is_out_start_touch = false
    ex = null
    ey = null

    game.rootScene.addEventListener Event.ENTER_FRAME, () ->
      if is_touch
        dx = ex - game.width / 2
        dy = ey - game.height / 2
        va = ElzupUtils.vec_maguniture(dx, dy)

        if is_out_start_touch
          va *= 10
        emit_move(dx / va, dy / va, va)

    game.rootScene.addEventListener Event.TOUCH_START, (e) ->
      ex = e.x
      ey = e.y
      is_out_start_touch = RADIUS_ACTION < ElzupUtils.vec_maguniture(ex - game.width / 2, ey - game.height / 2)
      is_touch = true
    game.rootScene.addEventListener Event.TOUCH_END, (e) ->
      is_out_start_touch = false
      is_touch = false

    game.rootScene.addEventListener Event.TOUCH_MOVE, (e) ->
      ex = e.x
      ey = e.y

  game.start()

  get_params = ElzupUtils.get_parameters()
  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url
  # TODO: team
  socket.emit 'new',
    type: get_params['type']
    team: get_params['team']


  # スマホのシェイクイベントを取得
  # TODO: remove act:
  emit_shake = ->
    socket.emit 'shake',
      act: 'swim'

  emit_move = (dx, dy, radius=false) ->
    console.log(dx, dy, radius)
    socket.emit 'move',
      dx: dx
      dy: dy
      radius: radius

  # 新規ユーザ作成
  $(@).gShake -> emit_shake()
