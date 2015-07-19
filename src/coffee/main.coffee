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

PLAYER_DIE_RADIUS = 100

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
  wall: 2
  vortex: 3
  sprite: 4
STAGE = [0, 2, 3, 4][Math.floor(Math.random() * 4)]

Frame =
  pointer_black: 0
  pointer: 1
  plus_stand: 0
  plus_walk: 1
  plus_walk2: 2
  plus_swim: 3

# GAME_TIME_LIMIT_SEC = 90
GAME_TIME_LIMIT_SEC = 90
GAME_TIME_PRE_FINISH = parseInt(GAME_TIME_LIMIT_SEC / 6)
FOOTER_HEIGHT = 80

# SCORE_AVG = MAP_WIDTH_NUM * MAP_HEIGHT_NUM / 4
init_pos = [
  {
    x: MAP_WIDTH / 7
    y: MAP_HEIGHT / 10
  }, {
    x: MAP_WIDTH * 6 / 7
    y: MAP_HEIGHT / 10
  }, {
    x: MAP_WIDTH / 7
    y: MAP_HEIGHT * 6 / 10
  }, {
    x: MAP_WIDTH * 6 / 7
    y: MAP_HEIGHT * 9 / 10
  }
]

V_SHOT = 40.0
V_SUPER_SHOT = 200.0
V_ROLLER = 20.0

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

$ ->
  # enchant game
  enchant()

  # core setting
  game = new Core(MAP_WIDTH, MAP_HEIGHT + FOOTER_HEIGHT)
  game.preload('/images/bear.png', '/images/icon0.png', '/images/map0.png', '/images/item.png')
  game.fps = FPS

  # global
  # NOTE: term 言い回しは正当？
  game_term = null

  player_group = null

  map = null
  baseMap = null

  timer_label = null
  score_bar = null
  score_cover = null
  score = null

  game_start_time = 0

  # socket io
  socket = io.connect()

  Player = enchant.Class.create enchant.Sprite,
    id: null
    sp: PLAYER_SPEED
    pos: new Victor(0, 0)
    v: new Victor(0, 0)
    a: new Victor(0.8, 0.8)
    pre_pos: new Victor(0, 0)
    team: 0
    type: PlayerType.gun
    col: null
    last_shot_frame: 0
    is_swim: false
    is_die: false
    pointer: null
    delay: SHOT_RAPID_DELAY
    initialize: (@id, @team, @type) ->
      enchant.Sprite.call(@, 32, 32)
      switch @type
        when PlayerType.gun
          @delay = SHOT_RAPID_DELAY
        when PlayerType.rifle
          @delay = SUPERSHOT_RAPID_DELAY

      @moveTo(init_pos[@team].x * MAP_MATRIX_SIZE, init_pos[@team].y * MAP_MATRIX_SIZE)
      @image = game.assets['/images/bear.png']
      @frame = @team * 5
      @col = COL_LIB[@team]
      @_style.zIndex = -PLAYER_Z_SHIFT
      player_group.addChild(@)

    shot: (x, y)->
      # TODO:
      console.log "shot"

    reloaded: ->
      game.frame - @last_shot_frame > @delay

    walk: (@rad, @pow) ->
      mr = @pow / 90
      @v.add new Victor(0, 2).rotate(-@rad).multiply(new Victor(mr, mr))
      @rotation = 180 - @rad * 180 / Math.PI

    onenterframe: ->
      if @is_swim
      else if @moved()
        @frame = @team * 5 + Frame.plus_walk + @age / 4 % 2
      else
        @frame = @team * 5 + Frame.plus_stand
      @pre_pos.copy(@pos)

      if @is_die
        return

      console.log(@pos)
      @pos.add(@v)
      @pos.limit(MAP_WIDTH, 1.0)
      @v.multiply(@a)
      if @v.length() < 0.5
        @v = new Victor(0, 0)
      @moveTo(@pos.x, @pos.y)

    moved: ->
      new Victor(0, 0).copy(@pre_pos).subtract(@pos).length() > 0

    swim: ->
      if @is_die
        return
      @is_swim = true
      @frame = @team * 5 + Frame.plus_swim
      @tl.delay(SWIM_TIME).then(@swim_end)
    swim_end: ->
      @frame = @team * 5 + Frame.plus_stand
      @is_swim = false
  # 2つのメソッドまとめる
    on_team_color: ->
      [mx, my] = map_pos(@ox(), @oy())
      baseMap[my][mx] == @team + COL_SHIFT
    on_enemy_color: ->
      [mx, my] = map_pos(@ox(), @oy())
      baseMap[my][mx] != 0 and baseMap[my][mx] != @team + COL_SHIFT

    die: ->
      @opacity = 0.5
      @is_die = true
      @tl.clear()
      @tl.moveTo(init_pos[@team].x * MAP_MATRIX_SIZE, init_pos[@team].y * MAP_MATRIX_SIZE, FPS / 2)
      .delay(FPS).and().repeat(->
        @opacity = @age % 2
      , FPS).then(->
        @opacity = 1.0
        @is_die = false
      )

    ox: ->
      @x + @width / 2
    oy: ->
      @y + @height / 2

    end_point: (vx, vy, cx = @x, cy = @y) ->
      px = if vx < 0 then cx else cx + @width
      py = if vy < 0 then cy else cy + @height
      [px, py]

    end_points: (cx = @x, cy = @y) ->
      [[cx, cy], [cx + @width, cy], [cx, cy + @height], [cx + @width, cy + @height]]


  game.onload = ->
    game_init()

  game.start()

  game_init = ->
    game.rootScene.remove()
    game_term = GameTerm.ready
    player_group = new Group()
    # player は手前

    for i, p of init_pos
      [x, y] = map_pos(p.x, p.y)
      init_pos[i].x = x
      init_pos[i].y = y
    map = new Map(MAP_MATRIX_SIZE, MAP_MATRIX_SIZE)
    map.image = game.assets['/images/map0.png']
    baseMap = create_map()
    map.loadData(baseMap)

    timer_label = new Label()
    timer_label.moveTo(MAP_WIDTH / 2 - 20, MAP_HEIGHT + 10)
    timer_label.font = '50px "ヒラギノ角ゴ ProN W3", "Hiragino Kaku Gothic ProN", "メイリオ", Meiryo, sans-serif'
    timer_label.addEventListener Event.ENTER_FRAME, ->
      if game_term != GameTerm.progress
        return
      progress = parseInt((game.frame - game_start_time) / game.fps)
      time = GAME_TIME_LIMIT_SEC - progress;
      @text = time + ""
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
          padding = 5
          if STAGE == Stage.blocks and padding < j < (MAP_HEIGHT_NUM - padding) and padding < i < (MAP_WIDTH_NUM - padding) and (i + 15) % span < col and (j + 15) % span < col
            baseMap[j][i] = BlockType.BLOCK
          if j == 0 or j == MAP_HEIGHT_NUM - 1 or i == 0 or i == MAP_WIDTH_NUM - 1
            baseMap[j][i] = BlockType.WALL
    else
      if STAGE == Stage.wall
        baseMap = Maps.wall()
      else if STAGE == Stage.vortex
        baseMap = Maps.vortex()
      else
        baseMap = Maps.sprite()
      for j in [0...MAP_HEIGHT_NUM]
        for i in [0...MAP_WIDTH_NUM]
          p = baseMap[j][i]
          if not is_block(p) and p != BlockType.NONE
            init_pos[p - 1] = { x: i, y: j }
    # else if STAGE == Stage.vortex
    # else if STAGE == Stage.sprite
    baseMap

  draw_pointer = (x, y, time, frame = Frame.pointer) ->
    pointer = new Sprite(32, 32)
    pointer.image = game.assets['/images/item.png']
    pointer.moveTo(x - pointer.width / 2, y - pointer.height / 2)
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
      fill_pos_circle(player.ox(), player.oy(), PLAYER_DIE_RADIUS, team)
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
          fill_pos_circle(player.ox(), player.oy(), PLAYER_DIE_RADIUS, team)
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

  socket.emit 'new',
    room: 'top'
  # TODO: remove debug outputs
  console.log('socket connect try')

  socket.on 'move', (data) ->
    player = get_player(data.id)
    if !player?
      return
    player.walk(data.rad, data.pow)

  socket.on 'shake', (data) ->
    # TODO: create action
    player = get_player(data.id)
    player.shot()

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

