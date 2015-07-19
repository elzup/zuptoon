MAP_WIDTH = 320
MAP_HEIGHT = 400

$ ->
  ### enchant.js ###
  enchant()

  game = new Core(MAP_WIDTH, MAP_HEIGHT)
  game.preload "images/apad.png"
  game.fps = 10

  game.onload = ->
    console.log "game onload"
    controller = new Sprite(100, 100)
    console.log game.assets
    controller.image = game.assets['images/apad.png']
    # controller.scale(controller.width, controller.height)
    scale_ratio = MAP_WIDTH / controller.width
    controller.scale(scale_ratio, scale_ratio)
    controller.moveTo(MAP_WIDTH / 2 - 50, MAP_HEIGHT / 2 - 50)
    game.rootScene.addChild(controller)

    is_touch = false
    is_touch_pre = false
    ex = null
    ey = null

    game.rootScene.addEventListener Event.ENTER_FRAME, () ->
      if is_touch
        [dx, dy, rad, pow] = get_vec(ex, ey)
        emit_move(rad, pow)
      if is_touch_pre and not is_touch
        emit_stop()
      is_touch_pre = is_touch

    game.rootScene.addEventListener Event.TOUCH_START, (e) ->
      ex = e.x
      ey = e.y
      is_touch = true
    game.rootScene.addEventListener Event.TOUCH_END, (e) ->
      is_touch = false

    game.rootScene.addEventListener Event.TOUCH_MOVE, (e) ->
      ex = e.x
      ey = e.y

    console.log "game onload end"
    return

  get_vec = (x, y) ->
    dx = x - MAP_WIDTH / 2
    dy = y - MAP_HEIGHT / 2
    rad = Math.atan2(dx, dy)
    va = ElzupUtils.vec_maguniture(dx, dy)
    rad = parseInt(rad * 100) / 100
    pow = ElzupUtils.clamp(parseInt(va), 100)
    return [dx, dy, rad, pow]

  game.start()

  ### socket.io ###
  socket = io.connect()

  get_params = ElzupUtils.get_parameters()
  socket.emit 'new',
    room: 'user'
    type: get_params['type']
    team: get_params['team']
  # TODO: remove debug outputs
  console.log('socket connect try')

  socket.on 'init_res', (data) ->
    console.log('socket connected id' + data.id)

  emit_move = (rad, pow) ->
    socket.emit 'move',
      rad: rad
      pow: pow
    console.log(rad, pow)

  emit_stop = ->
    emit_move(0, 0)

  emit_shake = ->
    console.log("shake")
    socket.emit 'shake'

  ($ this).gShake ->
    emit_shake()
