$ ->
  # enchant game
  enchant()

  # constants
  FPS = 20

  SPR_Z_SHIFT = 1000
  PLAYER_Z_SHIFT = 10000
  spr_count = 0
  SHOT_RAPID_DELAY = FPS / 5 # 0.2秒
  RADIUS_ACTION = 160 * 0.4
  COL_LIB = ['red', 'yellow', 'blue', 'green'];

  MAP_MATRIX_SIZE = 8
  MAP_WIDTH_NUM = 64 * 2
  MAP_HEIGHT_NUM = 48 * 2
  MAP_WIDTH = MAP_WIDTH_NUM * MAP_MATRIX_SIZE
  MAP_HEIGHT = MAP_HEIGHT_NUM * MAP_MATRIX_SIZE

  # TODO: set to 60?
  GAME_LIMIT_TIME_SEC = 20

  FOOTER_HEIGHT = 80

  INIT_POS = [
    {
      x: MAP_WIDTH / 7
      y: MAP_HEIGHT / 7
    }, {
      x: MAP_WIDTH * 6 / 7
      y: MAP_HEIGHT / 7
    }, {
      x: MAP_WIDTH / 7
      y: MAP_HEIGHT * 6 / 7
    }, {
      x: MAP_WIDTH * 6 / 7
      y: MAP_HEIGHT * 6 / 7
    }
  ]

  SWIM_TIME = FPS * 0.8 # 0.8秒
  PLAYER_SPEED = 1.0
  GameTerm =
    ready: 0
    progress: 1
    result: 2

  # map view type
  # 0: graphical
  # 1: matrix_fill
  # TODO: enum constains
  SHOW_TYPE = 1

  # core setting
  game = new Core(MAP_WIDTH, MAP_HEIGHT + FOOTER_HEIGHT)
  game.preload('/images/space3.png', '/images/icon0.png', '/images/map0.png')
  game.fps = FPS

  # global
  # NOTE: term 言い回しは正当？
  game_term = null

  player_group = null
  liquid_group = null

  liquid_sprite = null

  map = null
  baseMap = null

  timer_lavel = null
  score_bar = null

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url


  Liquid = enchant.Class.create enchant.Sprite,
    team: 0
    scaler: 2.0
    initialize: (x, y, vx, vy, team, vspeed = 30.0, scaler = 2.0) ->
      enchant.Sprite.call(this, 16, 16)
      spr_count += 1
      @.image = game.assets['/images/icon0.png']
      @.scaler = scaler
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
      @.tl.scaleTo(@.scaler, @.scaler, FPS / 2).then(->
        fill_pos_circle(@.x + @.width / 2, @.y + @.width / 2, @.r(), @.team)
        @.parentNode.removeChild(@)
      )
      kill_player_circle(@.x, @.y, @.r(), @.team)
    r: ->
      @.width * @.scaleX / 2


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
      if @.is_die
        return
      # TODO: 三方向ショット
      new Liquid(@.x, @.y, @.dx, @.dy, @.team, 60.0, 4)
    shot: (vsp)->
      if @.is_die
        return
      frame = game.frame
      # 即連射, swim中 禁止
      if frame - @.last_shot_frame < SHOT_RAPID_DELAY || @.is_swim
        return
      # ランダムでずらす
      rr = Math.random() * 0.5
      new Liquid(@.x, @.y, @.dx, @.dy, @.team, 20.0 * vsp, 2.0 + rr)
      @.last_shot_frame = frame

    walk: (dx, dy) ->
      if @.is_die
        return
      sp = @.sp
      # swim モードでかつプレイヤーの位置がチーム色の場合
      if @.is_swim && @.on_team_color()
        sp *= 4
      nx = ElzupUtils.clamp(@.x + dx * sp, MAP_WIDTH - @.width)
      ny = ElzupUtils.clamp(@.y + dy * sp, MAP_HEIGHT - @.height)
      @.moveTo(nx, ny)
      @.dx = dx
      @.dy = dy
      @.scaleX = if dx > 0 then 1 else -1

    swim: ->
      if @.is_die
        return
      @.is_swim = true
      @.frame = @.team * 5 + 2
      @.tl.delay(SWIM_TIME).then(->
        @.frame = @.team * 5
        @.is_swim = false
      )
    on_team_color: ->
      [mx, my] = get_map_pos(@.x, @.y, @.width)
      baseMap[my][mx] == @.team + 1
    id_die: false

    die: ->
      @.is_die = true
      @.opacity = 0.5
      @.tl.moveTo(INIT_POS[@.team].x, INIT_POS[@.team].y, FPS).delay(FPS).and()
        .repeat(->
          @.opacity = @.age % 2
        , FPS).then(->
          @.opacity = 1.0
          @.is_die = false
        )


  game.onload = ->
    game_init()

  game.start()

  game_init = ->
    game_term = GameTerm.ready
    # create liquid image
    player_group = new Group()
    liquid_group = new Group()
    # player は手前

    map = new Map(MAP_MATRIX_SIZE, MAP_MATRIX_SIZE)
    map.image = game.assets['/images/map0.png']
    baseMap = create_map()
    map.loadData(baseMap)

    liquid_sprite = new Sprite(MAP_WIDTH, MAP_HEIGHT)
    liquid_sprite.image = new Surface(MAP_WIDTH, MAP_HEIGHT)

    timer_label = new Label()
    timer_label.moveTo(MAP_WIDTH / 2 - 20, MAP_HEIGHT + 10)
    timer_label.font = '50px "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN", "メイリオ", Meiryo, sans-serif'
    timer_label.addEventListener Event.ENTER_FRAME, ->
      progress = parseInt(game.frame / game.fps)
      time = GAME_LIMIT_TIME_SEC - progress + "";
      @.text = time

    score_bar = new Sprite(MAP_WIDTH, FOOTER_HEIGHT)
    score_bar.image = new Surface(MAP_WIDTH, FOOTER_HEIGHT)

    score_cover = new Sprite(MAP_WIDTH, FOOTER_HEIGHT * 0.25)
    score_cover.backgroundColor = "gray"

    game.rootScene.backgroundColor = "#AAA";
    game.rootScene.addChild(map)
    game.rootScene.addChild(liquid_sprite)
    game.rootScene.addChild(liquid_group)
    game.rootScene.addChild(player_group)
    game.rootScene.addChild(score_cover)
    game.rootScene.addChild(score_bar)
    game.rootScene.addChild(timer_label)

  create_map = ->
    baseMap = [0...MAP_HEIGHT_NUM]
    for i in baseMap
      baseMap[i] = [0...MAP_WIDTH_NUM]
      for j in baseMap[i]
        baseMap[i][j] = 0
        if i == 0 or i == MAP_HEIGHT_NUM - 1 or j == 0 or j == MAP_WIDTH_NUM - 1
          baseMap[i][j] = 32
    baseMap


  fill_pos_circle = (x, y, r, team) ->
    draw_circle(x, y, r, COL_LIB[team])
    [mx, my] = get_map_pos(x, y)
    mr = Math.floor(r / MAP_MATRIX_SIZE)
    mr2 = mr * mr
    for j in [-mr..mr]
      for i in [-mr..mr]
        if j * j + i * i > mr2
          continue
        fill_map(mx + i, my + j, team)
    if SHOW_TYPE == 1
      map.loadData(baseMap)

  fill_pos = (mx, my, team, mr = 1) ->
    for j in [-mr..mr]
      for i in [-mr..mr]
        fill_map(mx + i, my + j, team)
    if SHOW_TYPE == 1
      map.loadData(baseMap)

  fill_map = (mx, my, team) ->
    if ElzupUtils.clamp(my, MAP_HEIGHT_NUM - 1) != my || ElzupUtils.clamp(mx, MAP_WIDTH_NUM - 1) != mx
      return
    baseMap[my][mx] = team + 1

  get_map_pos = (sx, sy, r = 0) ->
    mx = ElzupUtils.clamp(Math.floor((sx + r) / MAP_MATRIX_SIZE), MAP_WIDTH_NUM)
    my = ElzupUtils.clamp(Math.floor((sy + r) / MAP_MATRIX_SIZE), MAP_HEIGHT_NUM)
    [mx, my]

  draw_circle = (x, y, r, col) ->
    if SHOW_TYPE != 0
      return
    context = liquid_sprite.image.context
    context.beginPath()
    context.fillStyle = col
    context.arc
    context.arc(x, y, r, 0, Math.PI * 2)
    context.closePath()
    context.fill()

  get_player = (id) ->
    for player in player_group.childNodes
      if player.id == id
        return player
        break
    null

  kill_player_circle = (x, y, r, team) ->
    r2 = r * r
    for player in player_group.childNodes
      if player.team == team or player.is_die
        continue
      dx = player.x - x
      dy = player.y - y
      if dx * dx + dy * dy > r2
        continue
      fill_pos_circle(player.x + player.width / 2, player.y + player.height / 2, 50, team)
      player.die()

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
