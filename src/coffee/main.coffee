
$ ->
  # enchant game
  enchant()

  # core setting
  game = new Core(950, 480)
  game.preload('/images/chara1.png', '/images/icon0.png')
  game.fps = 20;

  # constants
  SPR_Z_SHIFT = 1000
  PLAYER_Z_SHIFT = 10000
  spr_count = 0
  SHOT_RAPID_DELAY = game.fps / 5
  RADIUS_ACTION = 320 * 0.4
  sp = 2.0

  player_group = null
  liquid_group = null

  Liquid = enchant.Class.create enchant.Sprite,
    col: 0
    r: 2.0
    initialize: (x, y, vx, vy, col, vspeed=30.0, r=2.0) ->
      enchant.Sprite.call(this, 16, 16)
      spr_count += 1
      @.image = game.assets['/images/icon0.png']
      @.col = col
      @.r = r
      @.moveTo(x + @.width / 2, y + @.height / 2)
      @.frame = 12
      @._style.zIndex = - SPR_Z_SHIFT
      @.tl.moveBy(vx * vspeed, vy * vspeed, 8).then -> @.pop()

      liquid_group.addChild(@)
    pop: ->
      @.scale(2.0, 2.0)
      sfc = new Surface(16, 16)
      ctx = sfc.context
      ctx.beginPath()
      ctx.arc(sfc.width / 2, sfc.height / 2, sfc.width / 2, 0, Math.PI * 2, false)
      ctx.fill()
      sfc.context.fillStyle = @.col
      sfc.context.fill()
      @.image = sfc
      @.tl.scaleTo(@.r, @.r, 10.0)

  col_lib = ['red', 'yellow', 'blue', 'green'];
  Player = enchant.Class.create enchant.Sprite,
    dx: 1
    dy: 0
    team: 0
    type: 0
    col: null
    id: null
    last_shot_frame: 0
    initialize: (id, team, type) ->
      enchant.Sprite.call(@, 32, 32)
      @.id = id
      @.team = team
      @.type = type
      @.frame = [6, 6, 7, 7]
      @.moveTo(game.width / 2 - @.width / 2, game.height / 2 - @.height / 2)
      @.image = game.assets['/images/chara1.png']
      @.frame = 5
      @.col = col_lib[team]
      console.log(@.col)
      @._style.zIndex = - PLAYER_Z_SHIFT
      player_group.addChild(@)
    supershot: ()->
      # 三方向ショット
      new Liquid(@.x, @.y, @.dx, @.dy, @.col, 60.0, 4)
    shot: (vsp)->
      frame = game.frame
      # 即連射禁止
      if frame - @.last_shot_frame < SHOT_RAPID_DELAY
        return
      new Liquid(@.x, @.y, @.dx, @.dy, @.col, 30.0 * vsp)
      @.last_shot_frame = frame

    walk: (dx, dy) ->
      nx = ElzupUtils.clamp(@.x + dx * sp, game.width - @.width)
      ny = ElzupUtils.clamp(@.y + dy * sp, game.height - @.height)
      @.moveTo(nx, ny)
      @.dx = dx
      @.dy = dy
      @.scaleX = if dx > 0 then 1 else -1

    swim: ()->
      console.log('swim')

  game.onload = ->

    # create liquid image
    player_group = new Group()
    liquid_group = new Group()
    # player は手前
    game.rootScene.backgroundColor = "#AAA";
    game.rootScene.addChild(liquid_group)
    game.rootScene.addChild(player_group)

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  get_player = (id) ->
    for player in player_group.childNodes
      if player.id == id
        return player
        break
    return null

  socket.on 'move', (data) ->
    player = get_player(data.id)
    if !player?
      return
    rate = data.radius / RADIUS_ACTION
    console.log(rate)
    if player.type == 0 && RADIUS_ACTION < data.radius
      player.walk(data.dx, data.dy)
      player.shot(rate)
    else
      player.walk(data.dx * rate, data.dy * rate)

  socket.on 'shake', (data) ->
    player = get_player(data.id)
    if !player?
      return
    switch player.type
      when 0
        player.swim()
      when 1
        player.supershot()
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)

  socket.on 'createuser', (data) ->
    console.log('create user')
    console.log(data)
    player = new Player(data.id, parseInt(data.team), parseInt(data.type + 0))
    player_group.addChild(player)

  socket.on 'removeuser', (data) ->
    console.log('delete user')
    console.log(data)
    player = get_player(data.id)
    player_group.removeChild(player)
