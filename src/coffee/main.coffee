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

  QUICK_DEBUG = 0

  MAP_MATRIX_SIZE = 8
  MAP_WIDTH_NUM = 64 * 2
  MAP_HEIGHT_NUM = 48 * 2
  MAP_WIDTH = MAP_WIDTH_NUM * MAP_MATRIX_SIZE
  MAP_HEIGHT = MAP_HEIGHT_NUM * MAP_MATRIX_SIZE

  GAME_TIME_LIMIT_SEC = 10000
  GAME_TIME_PRE_FINISH = parseInt(GAME_TIME_LIMIT_SEC / 6)
  FOOTER_HEIGHT = 80
  Controller =
    left: 0
    right: 1

  SCORE_AVG = MAP_WIDTH_NUM * MAP_HEIGHT_NUM / 4

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

  SWIM_TIME = FPS * 2
  PLAYER_SPEED = 2.0
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
  player_list = null
  liquid_group = null

  liquid_sprite = null

  map = null
  baseMap = null

  timer_label = null
  score_bar = null
  score_cover = null
  score = null

  game_start_time = 0

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
        fill_pos_circle(@.ox(), @.oy(), @.r(), @.team)
        @.parentNode.removeChild(@)
      )
      r = @.width * @.scaler / 2
      kill_player_circle(@.x, @.y, r, @.team)
      # DEBUG: kill する範囲を黒で塗りつぶす debug で大事
      # draw_circle(@.ox(), @.oy(), r, 'black', true)

    r: ->
      @.width * @.scaleX / 2
    ox: ->
      @.x + @.width / 2
    oy: ->
      @.y + @.height / 2

  Player = enchant.Class.create enchant.Sprite,
    id: null
    sp: PLAYER_SPEED
    dx: 0
    dy: 0
    team: 0
    type: 0
    col: null
    last_shot_frame: 0
    is_swim: false
    is_die: false
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
    shot: (x, y)->
      if @.is_die
        return
      frame = game.frame
      # 即連射, swim中 禁止
      if frame - @.last_shot_frame < SHOT_RAPID_DELAY
        return
      if @.is_swim
        @.swim_end()
      # ランダムでずらす
      rr = Math.random() * 0.5
      new Liquid(@.x, @.y, x, y, @.team, 40.0, 3.0 + rr)
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
      @.tl.delay(SWIM_TIME).then(@.swim_end)
    swim_end: ->
      @.frame = @.team * 5
      @.is_swim = false
    on_team_color: ->
      [mx, my] = get_map_pos(@.x, @.y, @.width)
      baseMap[my][mx] == @.team + 1

    die: ->
      console.log('die start')
      @.opacity = 0.5
      @.is_die = true
      @.tl.clear()
      @.tl.moveTo(INIT_POS[@.team].x, INIT_POS[@.team].y, FPS / 2)
      .delay(FPS).and().repeat( ->
        @.opacity = @.age % 2
      , FPS).then( ->
        @.opacity = 1.0
        @.is_die = false
        console.log('die end')
        console.log('die end')
      )
    ox: ->
      @.x + @.width / 2
    oy: ->
      @.y + @.height / 2

  game.onload = ->
    game_init()

  game.start()

  game_init = ->
    game.rootScene.remove()
    game_term = GameTerm.ready
    # create liquid image
    player_group = new Group()
    liquid_group = new Group()
    player_list = []
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
      if game_term != GameTerm.progress
        return
      progress = parseInt((game.frame - game_start_time) / game.fps)
      time = GAME_TIME_LIMIT_SEC - progress;
      @.text = time + ""
      # if (time <= GAME_TIME_PRE_FINISH)
      #   timer_label.tl.scaleTo(1, 1).scaleTo(1.5, 1.5, FPS * 0.6).delay(FPS * 0.4)
      if (time == GAME_TIME_PRE_FINISH)
        score_cover.tl.scaleTo(1.0, 1.0, FPS * GAME_TIME_PRE_FINISH)
          .delay(FPS * 1).scaleTo(0, 1.0, FPS * 3).then ->
            game.rootScene.removeChild(@)

      if (time == 0)
        game_result()

    score_bar = new Sprite(MAP_WIDTH, FOOTER_HEIGHT)
    score_bar.image = new Surface(MAP_WIDTH, FOOTER_HEIGHT)
    score_bar.moveTo(0, MAP_HEIGHT)

    score_cover = new Sprite(MAP_WIDTH * 0.5, FOOTER_HEIGHT)
    score_cover.backgroundColor = "gray"
    score_cover.scale(0, 1.0)
    score_cover.moveTo(MAP_WIDTH * 0.75, MAP_HEIGHT)

    score = [0, 0, 0, 0]

    btn = new Button("Start");
    margin = 20
    btn.moveTo(margin, MAP_HEIGHT + margin)
    btn.ontouchstart = ->
      game.rootScene.removeChild(@)
      game_start()

    game.rootScene.backgroundColor = "#AAA";
    game.rootScene.addChild(map)
    game.rootScene.addChild(liquid_sprite)
    game.rootScene.addChild(liquid_group)
    game.rootScene.addChild(player_group)
    game.rootScene.addChild(score_bar)
    game.rootScene.addChild(score_cover)
    game.rootScene.addChild(btn)
    game.rootScene.addChild(timer_label)

  game_start = ->
    game_term = GameTerm.progress
    game_start_time = game.frame

  game_result = ->
    game_term = GameTerm.result

    btn = new Button("Ready");
    margin = 20
    btn.moveTo(margin, MAP_HEIGHT + margin)
    btn.ontouchstart = ->
      game.rootScene.removeChild(@)
      game_init()
    game.rootScene.addChild(btn)

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
    # NOTE: マップに対する変更箇所全てに必要
    update_score()

  fill_pos = (mx, my, team, mr = 1) ->
    for j in [-mr..mr]
      for i in [-mr..mr]
        fill_map(mx + i, my + j, team)
    if SHOW_TYPE == 1
      map.loadData(baseMap)

  fill_map = (mx, my, team) ->
    if ElzupUtils.clamp(my, MAP_HEIGHT_NUM - 2, 1) != my || ElzupUtils.clamp(mx, MAP_WIDTH_NUM - 2, 1) != mx
      return
    pre = baseMap[my][mx]
    if pre == team + 1
      return
    baseMap[my][mx] = team + 1
    # スコア更新
    score[team] += 1
    if pre == 0
      return
    score[pre - 1] -= 1

  get_map_pos = (sx, sy, r = 0) ->
    mx = ElzupUtils.clamp(Math.floor((sx + r) / MAP_MATRIX_SIZE), MAP_WIDTH_NUM)
    my = ElzupUtils.clamp(Math.floor((sy + r) / MAP_MATRIX_SIZE), MAP_HEIGHT_NUM)
    [mx, my]

  draw_circle = (x, y, r, col, force = false) ->
    if SHOW_TYPE != 0 and ! force
      return
    context = liquid_sprite.image.context
    context.beginPath()
    context.fillStyle = col
    context.arc(x, y, r, 0, Math.PI * 2)
    context.closePath()
    context.fill()

  get_player = (id) ->
    for player in player_list
      if player.id == id
        return player
        break
    null

  kill_player_circle = (x, y, r, team) ->
    r2 = r * r
    for player in player_list
      console.log('c player')
      console.log(player.id)
      console.log(player.is_die)
      if player.team == team or player.is_die
        continue
      dx = player.ox() - x
      dy = player.oy() - y
      if dx * dx + dy * dy > r2
        continue
      console.log('k ' + player)
      fill_pos_circle(player.ox() , player.oy(), 50, team)
      console.log(team + ' => ' + player.id)
      player.die()

  update_score = ->
    max = Math.max.apply(null, score)
    context = score_bar.image.context
    context.beginPath()
    context.clearRect(0, 0, MAP_WIDTH, FOOTER_HEIGHT)
    for i in [0..3]
      context.fillStyle = COL_LIB[i]
      # 右端からトップチームを100% とした割合
      h = FOOTER_HEIGHT * i / 4
      context.fillRect(0, h, score[i] * MAP_WIDTH / max, h + FOOTER_HEIGHT / 4 - 1)
    context.closePath()
    context.fill()

  to_xy = (rad) ->
    x = Math.cos(rad)
    y = Math.sin(rad)
    return [x, y]

  socket.on 'move', (data) ->
    player = get_player(data.id)
    if !player?
      return
    [x, y] = to_xy(data.rad)
    # 左コントローラは移動
    if data.con == Controller.left
      rate = data.pow * 0.005 + 1
      player.walk(x * rate, y * rate)
    else
      if game_term != GameTerm.progress and !QUICK_DEBUG
        return
      # 中心付近のタッチは swim
      if data.pow < 30
        player.swim()
      else
        # (data.pow - 30) / 70 * 0.4 + 0.8
        rate = (data.pow - 30) * 4 / 700 + 0.8
        player.shot(x * rate, y * rate)

  socket.on 'shake', (data) ->
    player = get_player(data.id)
    if !player? or game_term != GameTerm.progress
      return
    console.log(player.type)
    switch player.type
      when 0
        player.swim()
      when 1
        player.supershot()

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    # console.log(data)

  socket.on 'createuser', (data) ->
    console.log('create user')
    console.log(data)
    player = new Player(data.id, parseInt(data.team), parseInt(data.type))
    console.log(player_list)
    player_list.push(player)
    console.log(player_list)

  socket.on 'removeuser', (data) ->
    console.log('delete user')
    console.log(data)
    player = get_player(data.id)
    player_group.removeChild(player)
    i = player_list.indexOf(player)
    if i in player_list
      console.log(player_list)
      player_list.splice(i, 1)
      console.log(player_list)
