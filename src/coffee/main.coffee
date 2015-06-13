$ ->
  # enchant game
  enchant()

  # constants
  FPS = 20

  SPR_Z_SHIFT = 1000
  PLAYER_Z_SHIFT = 10000
  spr_count = 0
  SHOT_RAPID_DELAY = FPS * 0.2
  SUPERSHOT_RAPID_DELAY = FPS * 1.0
  COL_LIB = ['red', 'yellow', 'blue', 'green']
  COL_SHIFT = 1
  # カフェラッテ
  # COL_SHIFT = 33 #
  # COL_LIB = ['#B58238', '#BE9562', '#8A4E1E', '#5B3417']

  QUICK_DEBUG = 0

  MAP_MATRIX_SIZE = 8
  MAP_WIDTH_NUM = 64 * 2
  MAP_HEIGHT_NUM = 48 * 2
  MAP_WIDTH = MAP_WIDTH_NUM * MAP_MATRIX_SIZE
  MAP_HEIGHT = MAP_HEIGHT_NUM * MAP_MATRIX_SIZE

  BlockType =
    NONE: 0
    COL_RED: 1 + COL_SHIFT
    COL_YELLOW: 2 + COL_SHIFT
    COL_BLUE: 3 + COL_SHIFT
    COL_GREEN: 4 + COL_SHIFT
    BLOCK: 5
    WALL: 6

  Stage =
    flat: 0
    blocks: 1
    bridge: 'stage1.json'
  STAGE = Stage.blocks

  Frame =
    pointer_black: 0
    pointer: 1
    plus_stand: 0
    plus_walk: 1
    plus_walk2: 2
    plus_swim: 3

  # GAME_TIME_LIMIT_SEC = 90
  GAME_TIME_LIMIT_SEC = 10000
  GAME_TIME_PRE_FINISH = parseInt(GAME_TIME_LIMIT_SEC / 6)
  FOOTER_HEIGHT = 80
  Controller =
    left: 0
    right: 1

  # SCORE_AVG = MAP_WIDTH_NUM * MAP_HEIGHT_NUM / 4
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

  V_SHOT = 40.0
  V_SUPER_SHOT = 200.0

  SWIM_TIME = FPS * 2
  PLAYER_SPEED = 1.5
  GameTerm =
    ready: 0
    progress: 1
    result: 2

  PlayerType =
    gun: 0
    rifle: 1
    roller: 2
    shotgun: 4

  # map view type
  # 0: graphical
  # 1: matrix_fill
  ShowType =
    graphical: 0
    matrix_fill: 1

  SHOW_TYPE = ShowType.matrix_fill

  # core setting
  game = new Core(MAP_WIDTH, MAP_HEIGHT + FOOTER_HEIGHT)
  game.preload('/images/bear.png', '/images/icon0.png', '/images/map0.png', '/images/item.png')
  game.fps = FPS

  # global
  # NOTE: term 言い回しは正当？
  game_term = null

  player_group = null
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

  LiquidType =
    simple: 0
    line: 1

  Liquid = enchant.Class.create enchant.Sprite,
    sx: 0
    sy: 0
    team: 0
    type: 0
    scaler: 2.0
    vx: 0
    vy: 0

    initialize: (x, y, vx, vy, team, scaler = 2.0, type = LiquidType.simple) ->
      enchant.Sprite.call(this, 16, 16)
      spr_count += 1
      @.sx = x
      @.sy = y
      @.vx = vx
      @.vy = vy
      @.image = game.assets['/images/icon0.png']
      @.scaler = scaler
      @.type = type
      @.moveTo(x + @.width / 2, y + @.height / 2)
      @.frame = 12
      @._style.zIndex = -SPR_Z_SHIFT
      @.team = team

    start: ->
      # ランダムでずらす
      rx = (Math.random() - 0.5) * 16
      ry = (Math.random() - 0.5) * 16
      px = @.vx + rx
      py = @.vy + ry
      sp = 8
      if @.type == LiquidType.line
        fill_pos_line(@.ox(), @.oy(), @.ox() + px, @.oy() + py, @.team)
        kill_player_line(@.ox(), @.oy(), @.ox() + px, @.oy() + py, @.team)
        sp = 4
      @.tl.moveBy(px, py, sp).then -> @.pop()
      # if @.type == LiquidType.simple
      #   draw_pointer(@.x + px, @.y + py, FPS)
      liquid_group.addChild(@)

    pop: ->
      @.scale(@.scaler * 0.8, @.scaler * 0.8)
      sfc = new Surface(16, 16)
      ctx = sfc.context
      ctx.beginPath()
      ctx.arc(sfc.width / 2, sfc.height / 2, sfc.width / 2, 0, Math.PI * 2, false)
      ctx.fill()
      sfc.context.fillStyle = COL_LIB[@.team]
      sfc.context.fill()
      @.image = sfc
      delay = FPS * 0.5
      if @.type == LiquidType.line
        delay = FPS * 0.1
      @.tl.scaleTo(@.scaler, @.scaler, delay).then(->
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
    pre_x: 0
    pre_y: 0
    team: 0
    type: PlayerType.gun
    col: null
    last_shot_frame: 0
    is_swim: false
    is_die: false
    pointer: null
    delay: SHOT_RAPID_DELAY
    initialize: (id, team, type) ->
      enchant.Sprite.call(@, 32, 32)
      @.id = id
      @.team = team
      @.type = type
      switch type
        when PlayerType.gun
          @.delay = SHOT_RAPID_DELAY
        when PlayerType.rifle
          @.delay = SUPERSHOT_RAPID_DELAY

      @.moveTo(INIT_POS[team].x, INIT_POS[team].y)
      @.image = game.assets['/images/bear.png']
      @.frame = team * 5
      @.col = COL_LIB[team]
      @._style.zIndex = -PLAYER_Z_SHIFT
      player_group.addChild(@)

    shot: (x, y)->
      if @.is_die
        return
      # 即連射, swim中 禁止
      if not @.reloaded()
        return
      if @.is_swim
        @.swim_end()
      # ランダムでずらす
      rr = Math.random() * 0.5
      scaler = rr + 3.0
      type = LiquidType.simple
      if @.type == PlayerType.rifle
        scaler = 1
        x *= V_SUPER_SHOT
        y *= V_SUPER_SHOT
        type = LiquidType.line

      liquid = new Liquid(@.x, @.y, x, y, @.team, scaler, type)
      liquid.start()
      @.last_shot_frame = game.frame

    update_pointer: (x, y)->
      px = @x + x
      py = @y + y
      draw_pointer(px, py, 3, if @.reloaded() then Frame.pointer else Frame.pointer_black)

    reloaded: ->
      game.frame - @.last_shot_frame > @.delay

    walk: (dx, dy) ->
      if @.is_die
        return
      sp = @.sp
      # swim モードでかつプレイヤーの位置がチーム色の場合
      if @.is_swim && @.on_team_color()
        sp *= 4
      else if @.on_enemy_color()
        sp *= 0.5
      # 精度が変わる部分
      for i in [1..5]
        nx = ElzupUtils.clamp(@.x + dx * sp / i, MAP_WIDTH - @.width)
        ny = ElzupUtils.clamp(@.y + dy * sp / i, MAP_HEIGHT - @.height)
        safe = true
        for p in @.end_points(nx, ny)
          [px, py] = p
          block_type = map_type(px, py)
          if is_block(block_type)
            safe = false
        if !safe
          continue
        @.moveTo(nx, ny)
        @.dx = dx
        @.dy = dy
        if @.type == PlayerType.roller and game_term == GameTerm.progress
          [vx, vy] = ElzupUtils.vec_vertical(dx, dy)
          V_ROLLER = 20.0
          npx1 = ElzupUtils.clamp(@.ox() + dx * sp * V_ROLLER + vy * V_ROLLER, MAP_WIDTH - @.width)
          npy1 = ElzupUtils.clamp(@.oy() + dy * sp * V_ROLLER + vx * V_ROLLER, MAP_HEIGHT - @.height)
          npx2 = ElzupUtils.clamp(@.ox() + dx * sp * V_ROLLER - vy * V_ROLLER, MAP_WIDTH - @.width)
          npy2 = ElzupUtils.clamp(@.oy() + dy * sp * V_ROLLER - vx * V_ROLLER, MAP_HEIGHT - @.height)
          # console.log('c', @.ox(), @.oy())
          # console.log('c', @.ox() + dx * sp * V_ROLLER, @.oy() + dy * sp * V_ROLLER + dx * V_ROLLER)
          # console.log('c', npx1, npy1, npx2, npy2)
          fill_pos_line(npx1, npy1, npx2, npy2, @.team)
          kill_player_line(npx1, npy1, npx2, npy2, @.team)
          # fill_pos_circle(npx1, npy1, 2, @.team + 1)
          # fill_pos_circle(npx2, npy2, 2, @.team + 1)

        @.scaleX = if dx > 0 then 1 else -1

    onenterframe: ->
      if @.is_swim
      else if @.moved()
        @.frame = @.team * 5 + Frame.plus_walk + @.age / 4 % 2
      else
        @.frame = @.team * 5 + Frame.plus_stand
      [@.pre_x, @.pre_y] = [@.x, @.y]

    moved: ->
      @.x != @.pre_x or @.y != @.pre_y

    swim: ->
      if @.is_die
        return
      @.is_swim = true
      @.frame = @.team * 5 + Frame.plus_swim
      @.tl.delay(SWIM_TIME).then(@.swim_end)
    swim_end: ->
      @.frame = @.team * 5 + Frame.plus_stand
      @.is_swim = false
  # 2つのメソッドまとめる
    on_team_color: ->
      [mx, my] = map_pos(@.ox(), @.oy())
      baseMap[my][mx] == @.team + COL_SHIFT
    on_enemy_color: ->
      [mx, my] = map_pos(@.ox(), @.oy())
      baseMap[my][mx] != 0 and baseMap[my][mx] != @.team + COL_SHIFT

    die: ->
      @.opacity = 0.5
      @.is_die = true
      @.tl.clear()
      @.tl.moveTo(INIT_POS[@.team].x, INIT_POS[@.team].y, FPS / 2)
      .delay(FPS).and().repeat(->
        @.opacity = @.age % 2
      , FPS).then(->
        @.opacity = 1.0
        @.is_die = false
      )

    ox: ->
      @.x + @.width / 2
    oy: ->
      @.y + @.height / 2

    end_point: (vx, vy, cx = @.x, cy = @.y) ->
      px = if vx < 0 then cx else cx + @.width
      py = if vy < 0 then cy else cy + @.height
      [px, py]

    end_points: (cx = @.x, cy = @.y) ->
      [[cx, cy], [cx + @.width, cy], [cx, cy + @.height], [cx + @.width, cy + @.height]]


  game.onload = ->
    game_init()

  game.start()

  game_init = ->
    game.rootScene.remove()
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
      if game_term != GameTerm.progress
        return
      progress = parseInt((game.frame - game_start_time) / game.fps)
      time = GAME_TIME_LIMIT_SEC - progress;
      @.text = time + ""
      # if (time <= GAME_TIME_PRE_FINISH)
      #   timer_label.tl.scaleTo(1, 1).scaleTo(1.5, 1.5, FPS * 0.6).delay(FPS * 0.4)
      if (time == GAME_TIME_PRE_FINISH)
        score_cover.tl.scaleTo(1.0, 1.0, FPS * GAME_TIME_PRE_FINISH)
        .delay(FPS).scaleTo(0, 1.0, FPS * 3).then ->
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
    baseMap = null
    if STAGE == Stage.flat or STAGE == Stage.blocks
      baseMap = [0...MAP_HEIGHT_NUM]
      for j in baseMap
        baseMap[j] = [0...MAP_WIDTH_NUM]
        for i in baseMap[j]
          baseMap[j][i] = 0
          span = 30
          col = 5
          if STAGE == Stage.blocks and (i + 30) % span < col and (j + 15) % span < col
            baseMap[j][i] = BlockType.BLOCK
          if j == 0 or j == MAP_HEIGHT_NUM - 1 or i == 0 or i == MAP_WIDTH_NUM - 1
            baseMap[j][i] = BlockType.WALL
    # else
    #   $.get STAGE, null, ->
    #     baseMap
    baseMap

  draw_pointer = (x, y, time, frame = Frame.pointer) ->
    pointer = new Sprite(16, 16)
    pointer.image = game.assets['/images/item.png']
    pointer.moveTo(x, y)
    pointer.frame = frame
    game.rootScene.addChild(pointer)
    pointer.tl.delay(time).then(->
      game.rootScene.removeChild(@)
    )

  fill_pos_circle = (x, y, r, team) ->
    draw_circle(x, y, r, COL_LIB[team])
    [mx, my] = map_pos(x, y)
    mr = Math.floor(r / MAP_MATRIX_SIZE)
    mr2 = mr * mr
    for j in [-mr..mr]
      for i in [-mr..mr]
        if j * j + i * i > mr2
          continue
        fill_map(mx + i, my + j, team)
    if SHOW_TYPE == ShowType.matrix_fill
      map.loadData(baseMap)
    # NOTE: マップに対する変更箇所全てに必要
    update_score()

  fill_map = (mx, my, team) ->
    if ElzupUtils.clamp(my, MAP_HEIGHT_NUM - 2, 1) != my || ElzupUtils.clamp(mx, MAP_WIDTH_NUM - 2, 1) != mx
      return
    pre = baseMap[my][mx]
    if pre == team + COL_SHIFT or is_block(pre)
      return
    baseMap[my][mx] = team + COL_SHIFT
    # スコア更新
    score[team] += 1
    if pre == 0
      return
    score[pre - 1] -= 1

  map_pos = (sx, sy, r = 0) ->
    mx = ElzupUtils.clamp(Math.floor((sx + r) / MAP_MATRIX_SIZE), MAP_WIDTH_NUM)
    my = ElzupUtils.clamp(Math.floor((sy + r) / MAP_MATRIX_SIZE), MAP_HEIGHT_NUM)
    [mx, my]

  map_type = (sx, sy) ->
    [mx, my] = map_pos(sx, sy)
    baseMap[my][mx]

  is_player_block_type = (type) ->
    COL_SHIFT <= type < COL_SHIFT + 4

  is_block = (type) ->
    type == BlockType.BLOCK or type == BlockType.WALL

  draw_circle = (x, y, r, col, force = false) ->
    if SHOW_TYPE != ShowType.graphical and !force
      return
    context = liquid_sprite.image.context
    context.beginPath()
    context.fillStyle = col
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
      dx = player.ox() - x
      dy = player.oy() - y
      if dx * dx + dy * dy > r2
        continue
      fill_pos_circle(player.ox(), player.oy(), 50, team)
      player.die()

  fill_pos_line = (x1, y1, x2, y2, team) ->
    c = 10
    for i in [0...c]
      px = x2 + (i / c) * (x1 - x2)
      py = y2 + (i / c) * (y1 - y2)
      [mx, my] = map_pos(px, py)
      for dx in [-1...2]
        for dy in [-1...2]
          fill_map(mx + dx, my + dy, team)
    if SHOW_TYPE == ShowType.matrix_fill
      map.loadData(baseMap)
    # graphical line
    update_score()

  kill_player_line = (x1, y1, x2, y2, team) ->
    # NOTE: 軽量化出来そうな処理
    c = 10
    for player in player_group.childNodes
      if player.team == team or player.is_die
        continue
      [mpx, mpy] = map_pos(player.ox(), player.oy())
      for i in [0...c]
        px = x2 + (i / c) * (x1 - x2)
        py = y2 + (i / c) * (y1 - y2)
        [mx, my] = map_pos(px, py)
        if (-1 <= mx - mpx <= 1 && -1 <= my - mpy <= 1)
          fill_pos_circle(player.ox(), player.oy(), 50, team)
          player.die()
          break


  update_score = ->
    max = Math.max.apply(null, score)
    context = score_bar.image.context
    context.beginPath()
    context.clearRect(0, 0, MAP_WIDTH, FOOTER_HEIGHT)
    for i in [0..3]
      context.fillStyle = COL_LIB[i]
      # 右端からトップチームを100% とした割合
      h = FOOTER_HEIGHT * i / 4
      context.fillRect(0, h, score[i] * MAP_WIDTH / max, FOOTER_HEIGHT / 4)
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
        switch player.type
          when PlayerType.gun
            rate *= V_SHOT
            player.shot(x * rate, y * rate)
            player.update_pointer(x * rate, y * rate)
          when PlayerType.rifle
            rate *= V_SUPER_SHOT
            player.update_pointer(x * rate, y * rate)

  socket.on 'shake', (data) ->
    # TODO: create action
    # player = get_player(data.id)

  socket.on 'leave', (data) ->
    player = get_player(data.id)
    if player.type == PlayerType.rifle
      rate = data.pow * 0.005 + 1
      [x, y] = to_xy(data.rad)
      if game_term != GameTerm.progress
        return
      player.shot(x * rate, y * rate)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)

  socket.on 'createuser', (data) ->
    console.log('create user')
    console.log(data)
    new Player(data.id, parseInt(data.team), parseInt(data.type))

  socket.on 'removeuser', (data) ->
    console.log('delete user')
    console.log(data)
    player = get_player(data.id)
    player_group.removeChild(player)
