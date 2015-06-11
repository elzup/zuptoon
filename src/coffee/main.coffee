$ ->
  # enchant game
  enchant()

  # core setting
  game = new Core(1024, 768)
  game.preload('/images/space3.png', '/images/icon0.png', '/images/map0.png')
  game.fps = 20;

  # constants
  SPR_Z_SHIFT = 1000
  PLAYER_Z_SHIFT = 10000
  spr_count = 0
  SHOT_RAPID_DELAY = game.fps / 5 # 0.2秒
  RADIUS_ACTION = 160 * 0.4
  COL_LIB = ['red', 'yellow', 'blue', 'green'];

  INIT_POS = [
    {
      x: game.width / 7
      y: game.height / 7
    }, {
      x: game.width * 6 / 7
      y: game.height / 7
    }, {
      x: game.width / 7
      y: game.height * 6 / 7
    }, {
      x: game.width * 6 / 7
      y: game.height * 6 / 7
    }
  ]

  SWIM_TIME = game.fps * 0.8 # 0.8秒
  PLAYER_SPEED = 2.0

  player_group = null
  liquid_group = null

  MAP_WIDTH = 64 * 2
  MAP_HEIGHT = 48 * 2
  MAP_SIZE = 8

  map = null
  baseMap = null

  Liquid = enchant.Class.create enchant.Sprite,
    team: 0
    r: 2.0
    initialize: (x, y, vx, vy, team, vspeed = 30.0, r = 2.0) ->
      enchant.Sprite.call(this, 16, 16)
      spr_count += 1
      @.image = game.assets['/images/icon0.png']
      @.r = r
      @.moveTo(x + @.width / 2, y + @.height / 2)
      @.frame = 12
      @._style.zIndex = -SPR_Z_SHIFT
      @.team = team
      # ランダムでずらす
      rx = (Math.random() - 0.5) * 16
      ry = (Math.random() - 0.5) * 16
      @.tl.moveBy(vx * vspeed + rx, vy * vspeed + ry, 8).then -> @.pop()

      liquid_group.addChild(@)
    pop: ->
      @.scale(2.0, 2.0)
      sfc = new Surface(16, 16)
      ctx = sfc.context
      ctx.beginPath()
      ctx.arc(sfc.width / 2, sfc.height / 2, sfc.width / 2, 0, Math.PI * 2, false)
      ctx.fill()
      sfc.context.fillStyle = COL_LIB[@.team]
      sfc.context.fill()
      @.image = sfc
      @.tl.scaleTo(@.r, @.r, 10.0)
      @.tl.hide()
      [mx, my] = get_map_pos(@.x, @.y, @.width / 2)

      fill_pos(mx, my, @.team + 1, 1)

  Player = enchant.Class.create enchant.Sprite,
    id: null
    sp: PLAYER_SPEED
    dx: 1
    dy: 0
    team: 0
    type: 0
    col: null
    last_shot_frame: 0
    is_swim: false
    initialize: (id, team, type) ->
      enchant.Sprite.call(@, 32, 32)
      @.id = id
      @.team = team
      @.type = type

      @.moveTo(INIT_POS[team].x, INIT_POS[team].y)
      @.image = game.assets['/images/space3.png']
      @.frame = team * 5
      @.col = COL_LIB[team]
      @._style.zIndex = -PLAYER_Z_SHIFT
      player_group.addChild(@)
    supershot: ()->
      # 三方向ショット
      console.log('super')
      new Liquid(@.x, @.y, @.dx, @.dy, @.team, 60.0, 4)
    shot: (vsp)->
      frame = game.frame
      # 即連射, swim中 禁止
      if frame - @.last_shot_frame < SHOT_RAPID_DELAY || @.is_swim
        return
      # ランダムでずらす
      rr = (Math.random() - 0.5) * 0.5
      new Liquid(@.x, @.y, @.dx, @.dy, @.team, 20.0 * vsp, 2.0 + rr)
      @.last_shot_frame = frame

    walk: (dx, dy) ->
      nx = ElzupUtils.clamp(@.x + dx * @.sp, game.width - @.width)
      ny = ElzupUtils.clamp(@.y + dy * @.sp, game.height - @.height)
      @.moveTo(nx, ny)
      @.dx = dx
      @.dy = dy
      @.scaleX = if dx > 0 then 1 else -1

    swim: ->
      @.sp = PLAYER_SPEED * 4
      @.is_swim = true
      @.frame = @.team * 5 + 2
      @.tl.delay(SWIM_TIME).then(->
        @.sp = PLAYER_SPEED
        @.frame = @.team * 5
        @.is_swim = false
      )

  game.onload = ->
    # create liquid image
    player_group = new Group()
    liquid_group = new Group()
    # player は手前

    map = new Map(MAP_SIZE, MAP_SIZE)
    map.image = game.assets['/images/map0.png']
    baseMap = [0...MAP_HEIGHT]
    for i in baseMap
      baseMap[i] = [0...MAP_WIDTH]
      for j in baseMap[i]
        baseMap[i][j] = 0
        if i == 0 or i == MAP_HEIGHT - 1 or j == 0 or j == MAP_WIDTH - 1
          baseMap[i][j] = 32
    map.loadData(baseMap)

    game.rootScene.backgroundColor = "#AAA";
    game.rootScene.addChild(map)
    game.rootScene.addChild(liquid_group)
    game.rootScene.addChild(player_group)

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  fill_pos = (mx, my, team, mr = 1) ->
    for j in [-mr..mr]
      for i in [-mr..mr]
        fill_map(mx + i, my + j, team)

    map.loadData(baseMap)

  fill_map = (mx, my, team) ->
    baseMap[ElzupUtils.clamp(my, MAP_HEIGHT)][ElzupUtils.clamp(mx, MAP_WIDTH)] = team

  get_map_pos = (sx, sy, r = 0) ->
    mx = ElzupUtils.clamp(Math.floor((sx + r) / MAP_SIZE), MAP_WIDTH)
    my = ElzupUtils.clamp(Math.floor((sy + r) / MAP_SIZE), MAP_HEIGHT)
    [mx, my]

  get_player = (id) ->
    for player in player_group.childNodes
      if player.id == id
        return player
        break
    null

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
    console.log(player.type)
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
    player = new Player(data.id, parseInt(data.team), parseInt(data.type))
    player_group.addChild(player)

  socket.on 'removeuser', (data) ->
    console.log('delete user')
    console.log(data)
    player = get_player(data.id)
    player_group.removeChild(player)
