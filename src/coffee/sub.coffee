$ ->
  # enchant game
  console.log('load main controller')
  enchant()
  game = new Core(480, 320)
  game.preload('/images/apad.png')
  game.fps = 20

  RADIUS_ACTION = 160 * 0.4

  BG_SIZE = 100

  CON_X = game.width / 4
  CON_Y = game.height / 2
  CON_X2 = game.width * 3 / 4
  CON_Y2 = CON_Y

  Controller =
    left: 0
    right: 1

  # action(shot)と判定するが中央からの距離
  RADIUS_ACTION = game.width * 0.4

  game.onload = ->

    # NOTE: game.rootScene#size game.root#size 違い
    # とりあえず画像のサイズ
    # 左コントローラ
    bg_left = new Sprite(BG_SIZE, BG_SIZE)
    bg_left.scale(game.height / 200, game.height / 200)
    bg_left.moveTo(CON_X - BG_SIZE / 2, CON_Y - BG_SIZE / 2)
    bg_left.image = game.assets['/images/apad.png']
    game.rootScene.addChild(bg_left)

    # 右コントローラ
    bg_right = new Sprite(BG_SIZE, BG_SIZE)
    bg_right.scale(game.height / 200, game.height / 200)
    bg_right.moveTo(CON_X2 - BG_SIZE / 2, CON_Y2 - BG_SIZE / 2)
    bg_right.image = game.assets['/images/apad.png']
    game.rootScene.addChild(bg_right)

    is_touch_l = false
    ex_l = null
    ey_l = null

    is_touch_r = false
    ex_r = null
    ey_r = null

    game.rootScene.addEventListener Event.ENTER_FRAME, () ->
      if is_touch_l
        dx = ex_l - CON_X
        dy = ey_l - CON_Y
        rad = get_rad(dx, dy)
        va = ElzupUtils.vec_maguniture(dx, dy)
        emit_move(rad, va, Controller.left)
      if is_touch_r
        dx = ex_r - CON_X2
        dy = ey_r - CON_Y2
        rad = get_rad(dx, dy)
        va = ElzupUtils.vec_maguniture(dx, dy)
        emit_move(rad, va, Controller.right)

    game.rootScene.addEventListener Event.TOUCH_START, (e) ->
      if e.x < game.width / 2
        is_touch_l = true
        ex_l = e.x
        ey_l = e.y
      else
        is_touch_r = true
        ex_r = e.x
        ey_r = e.y

    game.rootScene.addEventListener Event.TOUCH_END, (e) ->
      if e.x < game.width / 2
        is_touch_l = false
      else
        is_touch_r = false

    game.rootScene.addEventListener Event.TOUCH_MOVE, (e) ->
      if e.x < game.width / 2
        ex_l = e.x
        ey_l = e.y
      else
        ex_r = e.x
        ey_r = e.y

  game.start()

  get_rad = (x, y) ->
    Math.atan2(y, x)

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

  emit_move = (rad, pow, con) ->
    # varidate
    rad = parseInt(rad * 100) / 100
    pow = ElzupUtils.clamp(parseInt(pow), 100)
    console.log(rad, pow, con)

    socket.emit 'move',
      rad: rad
      pow: pow
      con: con

  # 新規ユーザ作成
  $(@).gShake -> emit_shake()
