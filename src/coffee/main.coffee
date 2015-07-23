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

MAP_M = 8
MAP_WIDTH_N = 64 * 2
MAP_HEIGHT_N = 48 * 2
MAP_WIDTH = MAP_WIDTH_N * MAP_M
MAP_HEIGHT = MAP_HEIGHT_N * MAP_M
MAP_M_VEC = new Victor(MAP_M, MAP_M)

PLAYER_DIE_RADIUS = 100
GAME_FONT = '50px "ヒラギノ角ゴ ProN W3",
 "Hiragino Kaku Gothic ProN", "メイリオ", Meiryo, sans-serif'

# global variables

core = null
game = null

zerovic = ->
  new Victor(0, 0)

clone = (v) ->
  new Victor(0, 0).copy(v)

Controller =
  left: 0
  right: 1

debug_surface = null

BlockType =
  NONE: 0
  COL_RED: 1 + COL_SHIFT
  COL_YELLOW: 2 + COL_SHIFT
  COL_BLUE: 3 + COL_SHIFT
  COL_GREEN: 4 + COL_SHIFT
  MP: 9
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
  None: -1
  pointer: 1
  Stand: 0
  Walk: 1
  Attack: 2
  Damage: 3
  Super: 4
  ItemShot: 2

# GAME_TIME_LIMIT_SEC = 90
GAME_TIME_LIMIT_SEC = 90
GAME_TIME_PRE_FINISH = parseInt(GAME_TIME_LIMIT_SEC / 6)
FOOTER_HEIGHT = 80

init_pos = [
  new Victor(MAP_WIDTH_N / 7, MAP_HEIGHT_N / 10)
  new Victor(MAP_WIDTH_N * 6 / 7, MAP_HEIGHT_N / 10)
  new Victor(MAP_WIDTH_N / 7, MAP_HEIGHT_N * 6 / 10)
  new Victor(MAP_WIDTH_N * 6 / 7, MAP_HEIGHT_N * 9 / 10)
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

class Game
  constructor: ->
    @players = {}
    @setup_map()

  onenterframe: ->
    for id, player of @players
      player.onenterframe()

  addPlayer: (id, team) ->
    player = new Player(id, team)
    @players[id] = player

  removePlayer: (id) ->
    if !@players[id]?
      return
    core.rootScene.removeChild(@players[id])
    delete @players[id]

  setup_map: ->
    @map = new Map(MAP_M, MAP_M)
    @map.image = core.assets['/images/map0.png']
    core.rootScene.addChild(@map)
    if STAGE == Stage.flat or STAGE == Stage.blocks
      @baseMap = [0...MAP_HEIGHT_N]
      for j in @baseMap
        @baseMap[j] = [0...MAP_WIDTH_N]
        for i in @baseMap[j]
          @baseMap[j][i] = 0
          span = 30
          col = 5
          padding = 5
          if STAGE == Stage.blocks and
              padding < j < (MAP_HEIGHT_N - padding) and
              padding < i < (MAP_WIDTH_N - padding) and
              (i + 15) % span < col and
              (j + 15) % span < col
            @baseMap[j][i] = BlockType.BLOCK
          if j == 0 or j == MAP_HEIGHT_N - 1 or i == 0 or i == MAP_WIDTH_N - 1
            @baseMap[j][i] = BlockType.WALL
      @map.loadData(@baseMap)
    else
      if STAGE == Stage.wall
        filename = "/data/map_wall.json"
      else if STAGE == Stage.vortex
        filename = "/data/map_vortex.json"
      else
        filename = "/data/map_sprite.json"
      $.getJSON filename, (data) =>
        @baseMap = data
        for j in [0...MAP_HEIGHT_N]
          for i in [0...MAP_WIDTH_N]
            p = @baseMap[j][i]
            if not Stage.is_block(p) and p != BlockType.NONE
              init_pos[p - 1] = new Victor(i, j)
        @map.loadData(@baseMap)
        console.log("map loaded")

  walk_player: (id, rad, pow) ->
    if !@players[id]?
      return
    @players[id].walk(rad, pow)

  dash_player: (id) ->
    if !@players[id]?
      return
    @players[id].dash()

  shot_player: (id, rad, pow) ->
    if !@players[id]?
      return
    @players[id].shot(rad, pow)

class Stage
  @is_block: (type) ->
    type in [BlockType.BLOCK, BlockType.WALL]

class Player
  id: null
  sp: PLAYER_SPEED
  pos: zerovic()
  v: zerovic()
  a: new Victor(0.8, 0.8)
  pre_pos: zerovic()
  team: 0
  col: null
  last_shot_frame: 0
  is_die: false
  mp: 100
  hp: 100
  pointer: null
  pre_shot_age: 0

  constructor: (@id, @team) ->
    @S = new Sprite(32, 32)
    @pos = clone(init_pos[@team]).multiply(MAP_M_VEC)
    @pos.subtract(new Victor(@r(), @r()))
    @S.moveTo(@pos.x, @pos.y)
    @S.image = core.assets['/images/player.png']
    @S.frame = @team * 5
    @col = COL_LIB[@team]
    @S._style.zIndex = -PLAYER_Z_SHIFT
    DomManager.addPlayerDom(this)
    DomManager.updatePlayerDom(this)
    core.rootScene.addChild(@S)

  damage: ->
    @hp -= 20
    if @hp <= 0
      @die()
    DomManager.updatePlayerDom(this)

  shotable: ->
    @pre_shot_age + SHOT_RAPID_DELAY < @S.age

  shot: (@rad, @pow)->
    if @mp < 5 or @is_die or not @shotable()
      return
    # TODO: mp 消費量バランス
    @mp -= 5
    console.log "shot"
    # mr = @pow / 90 * 10
    mr = 10
    v = new Victor(0, 1).rotate(-@rad).normalize().multiply new Victor(mr, mr)
    @pre_shot_age = @S.age

    pos = clone(@pos).add(clone(v).multiply(new Victor(3, 3)))
    shot = new Shot(pos, v, @team)
    core.rootScene.addChild(shot)
    @rotation = 180 - @rad * 180 / Math.PI
    update_dom(this)

  walk: (@rad, @pow) ->
    mr = @pow / 90
    @v.add new Victor(0, 2).rotate(-@rad).multiply(new Victor(mr, mr))
    if @shotable()
      @rotation = 180 - @rad * 180 / Math.PI

  dash: ->
    rad = Math.atan2(@v.x, @v.y)
    @walk(rad, 1000)

  onenterframe: ->
    if @moved()
      f = [Frame.Walk, Frame.Stand][ElzupUtils.period(@S.age, 8, 2)]
      @S.frame = @team * 5 + f
    else
      @S.frame = @team * 5 + Frame.Stand
    @pre_pos.copy(@pos)

    if @is_die
      return
    if @v.length() == 0
      return

    @check_conf_pos()
    @get_mps()
    # @pos.add(new Victor(vx, vy))
    @v.multiply(@a)
    if @v.length() < 0.5
      @v = zerovic()
    @S.moveTo(@pos.x, @pos.y)

  check_conf_pos: ->
    vx = @v.x
    vy = @v.y
    k = clone(@v)

    dx = Math.abs(vx)
    dy = Math.abs(vy)
    cposs = []
    for deg in [0...360] by 30
      rad = deg * Math.PI * 2 / 360
      cposs.push(to_xy(rad).multiply(new Victor(@r(), @r())).add(@opos()))

    for p in cposs
      tx = p.x + @v.x
      # mx, my 単体取得
      [msx, my] = to_mpos(p)
      mex = to_mx(tx)
      vxt = Math.abs vx
      msx += 1
      if @v.x < 0
        msx -= 2
      for mx in [msx..mex]
        if game.baseMap[my][mx] in [BlockType.BLOCK, BlockType.WALL]
          tsx = to_sx(mx)
          k.x = 0
          if @v.x >= 0
            vxt = tsx - p.x
          else
            vxt = p.x - (tsx + MAP_M)
          vxt -= 5
          break
      dx = Math.min(dx, vxt)

    if vx < 0
      dx *= -1
    @pos.x += dx

    for p in cposs
      ty = p.y + @v.y
      p.x += dx
      [tmp, msy] = to_mpos(p)
      mey = to_my(ty)
      vyt = Math.abs vy
      msy += 1
      if @v.y < 0
        msy -= 2
      for my in [msy..mey]
        if game.baseMap[my][mx] in [BlockType.BLOCK, BlockType.WALL]
          tsy = to_sy(my)
          k.y = 0
          if @v.y >= 0
            vyt = tsy - p.y
          else
            vyt = p.y - (tsy + MAP_M)
          vyt -= 5
          break
      dy = Math.min(dy, vyt)

    if vy < 0
      dy *= -1

    @pos.y += dy
    @v = k

  get_mps: ->
    [@msx, @msy] = to_mpos(@pos)
    [@mex, @mey] = to_mpos(new Victor(@pos.x + @width, @pos.y + @height))
    for my in [@msy..@mey]
      for mx in [@msx..@mex]
        if game.baseMap[my][mx] == BlockType.MP
          game.baseMap[my][mx] = BlockType.NONE
          @mp += 3
    update_dom(this)
    game.map.loadData(game.baseMap)


  moved: ->
    @v.length() != 0

  die: ->
    @opacity = 0.5
    @is_die = true
    # @S.frame = Frame.None
    # @diemove()

  diemove: ->
    @S.tl.clear()
    @S.tl.moveTo(init_pos[@team].x * MAP_M,
                      init_pos[@team].y * MAP_M,
                      FPS / 2)
    .delay(FPS).and().repeat(->
      @opacity = @S.age % 2
    , FPS).then(->
      @opacity = 1.0
      @is_die = false
    )

  r: ->
    @width / 2
  ox: ->
    @pos.x + @width / 2
  oy: ->
    @pos.y + @height / 2
  opos: ->
    new Victor(@ox(), @oy())

$ ->
  # enchant game
  enchant()

  # core setting
  core = new Core(MAP_WIDTH, MAP_HEIGHT + FOOTER_HEIGHT)
  core.preload ['/images/player.png'
    '/images/icon0.png'
    '/images/map0.png'
    '/images/item.png']
  core.fps = FPS

  # global
  # NOTE: term 言い回しは正当？
  game_term = null

  timer_label = null
  score_bar = null
  score_cover = null
  score = null

  game_start_time = 0

  # socket io
  socket = io.connect()

  Shot = enchant.Class.create enchant.Sprite,
    pos: zerovic()
    v: zerovic()
    a: new Victor(1.0, 1.0)
    mp: 5

    initialize: (@pos, @v, @team) ->
      enchant.Sprite.call(this, 32, 32)
      # TODO: group
      @image = core.assets['/images/item.png']
      @frame = Frame.ItemShot
      @moveTo(@pos.x, @pos.y)
      @S.tl.scaleTo(0.5, 0.5)
      rad = Math.atan2(@v.x, @v.y)
      @rotation = 180 - rad * 180 / Math.PI

    onenterframe: ->
      @pos.add(@v)
      @moveTo(@pos.x, @pos.y)
      # @v.multiply(@a)

      # ブロック衝突判定
      if map_type(@opos()) in [BlockType.BLOCK, BlockType.WALL]
        core.rootScene.removeChild(this)

      # MP の分布変更
      if @S.age % 10 == 0
        [mx, my] = to_mpos(@opos())
        console.log "k", game.baseMap[my][mx], [BlockType.BLOCK, BlockType.WALL]
        if game.baseMap[my][mx] not in [BlockType.WALL, BlockType.WALL]
          game.baseMap[my][mx] = BlockType.MP
          game.map.loadData(baseMap)
          @mp -= 1

      # プレイヤー衝突判定
      for id, player of @players
        if player.team == @team || player.is_die
          continue
        dx = player.ox() - @ox()
        dy = player.oy() - @oy()
        if dx * dx + dy * dy < Math.pow((@width / 2 + player.width) / 2, 2)
          player.v.add(@v.multiply(new Victor(3.0, 3.0)))
          core.rootScene.removeChild(this)
          player.damage()
          return

    r: ->
      @width / 2
    ox: ->
      @pos.x + @width / 2
    oy: ->
      @pos.y + @height / 2
    opos: ->
      new Victor(@ox(), @oy())

  core.onload = ->
    game = new Game

    ### debug init ###
    sp = new Sprite(2000, 2000)
    debug_surface = new Surface(2000, 2000)
    sp.image = debug_surface
    core.rootScene.addChild(sp)
    game_init()

  core.onenterframe = ->
    if game is null
      return
    game.onenterframe()

  core.start()

  game_init = ->
    core.rootScene.remove()
    game_term = GameTerm.ready
    # player は手前

    for i, p of init_pos
      init_pos[i] = to_mpos(p)

    timer_label = new Label()
    timer_label.moveTo(MAP_WIDTH / 2 - 20, MAP_HEIGHT + 10)
    timer_label.font = GAME_FONT
    timer_label.addEventListener Event.ENTER_FRAME, ->
      if game_term != GameTerm.progress
        return
      progress = parseInt((core.frame - game_start_time) / core.fps)
      time = GAME_TIME_LIMIT_SEC - progress
      @text = time + ""
      if (time == GAME_TIME_PRE_FINISH)
        score_cover.tl.scaleTo(1.0, 1.0, FPS * GAME_TIME_PRE_FINISH)
        .delay(FPS).scaleTo(0, 1.0, FPS * 3).then ->
          core.rootScene.removeChild(@)

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

    btn = new Button("Start")
    margin = 20
    btn.moveTo(margin, MAP_HEIGHT + margin)
    btn.ontouchstart = ->
      core.rootScene.removeChild(@)
      game_start()

    core.rootScene.backgroundColor = "#AAA"
    core.rootScene.addChild(score_bar)
    core.rootScene.addChild(score_cover)
    core.rootScene.addChild(btn)
    core.rootScene.addChild(timer_label)

  game_start = ->
    game_term = GameTerm.progress
    game_start_time = core.frame

  game_result = ->
    game_term = GameTerm.result

    btn = new Button("Ready")
    margin = 20
    btn.moveTo(margin, MAP_HEIGHT + margin)
    btn.ontouchstart = ->
      core.rootScene.removeChild(@)
      game_init()
    core.rootScene.addChild(btn)


  fill_pos_circle = (x, y, r, team) ->
    draw_circle(x, y, r, COL_LIB[team])
    [mx, my] = to_mpos(new Victor(x, y))
    mr = Math.floor(r / MAP_M)
    mr2 = mr * mr
    for j in [-mr..mr]
      for i in [-mr..mr]
        if j * j + i * i > mr2
          continue
        fill_map(mx + i, my + j, team)
    if SHOW_TYPE == ShowType.matrix_fill
      game.map.loadData(game.baseMap)
    # NOTE: マップに対する変更箇所全てに必要
    update_score()

  fill_map = (mx, my, team) ->
    if ElzupUtils.clamp(my, MAP_HEIGHT_N - 2, 1) != my or
        ElzupUtils.clamp(mx, MAP_WIDTH_N - 2, 1) != mx
      return
    pre = game.baseMap[my][mx]
    if pre == team + COL_SHIFT or Stage.is_block(pre)
      return
    game.baseMap[my][mx] = team + COL_SHIFT
    # スコア更新
    score[team] += 1
    if pre == 0
      return
    score[pre - 1] -= 1

  to_mpos = (spos, r = 0) ->
    [to_mx(spos.x + r), to_my(spos.y + r)]

  to_mx = (sx) ->
    ElzupUtils.clamp(Math.floor(sx / MAP_M), MAP_WIDTH_N - 1)

  to_my = (sy) ->
    ElzupUtils.clamp(Math.floor(sy / MAP_M), MAP_HEIGHT_N - 1)

  to_spos = (mx, my) ->
    new Victor(to_sx(mx), to_sy(my))

  to_sx = (mx) ->
    MAP_M * mx

  to_sy = (my) ->
    MAP_M * my


  map_type = (spos) ->
    [mx, my] = to_mpos(spos)
    game.baseMap[my][mx]

  is_player_block_type = (type) ->
    COL_SHIFT <= type < COL_SHIFT + 4

  draw_circle = (x, y, r, col, force = false) ->
    if SHOW_TYPE != ShowType.graphical and !force
      return

  kill_player_circle = (x, y, r, team) ->
    r2 = r * r
    for player in game.players
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
      [mx, my] = to_mpos(px, py)
      for dx in [-1...2]
        for dy in [-1...2]
          fill_map(mx + dx, my + dy, team)
    if SHOW_TYPE == ShowType.matrix_fill
      game.map.loadData(game.baseMap)
    # graphical line
    update_score()

  kill_player_line = (x1, y1, x2, y2, team) ->
    # NOTE: 軽量化出来そうな処理
    c = 10
    for player in game.players
      if player.team == team or player.is_die
        continue
      [mpx, mpy] = to_mpos(player.ox(), player.oy())
      for i in [0...c]
        px = x2 + (i / c) * (x1 - x2)
        py = y2 + (i / c) * (y1 - y2)
        [mx, my] = to_mpos(px, py)
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
    new Victor(Math.cos(rad), Math.sin(rad))

  socket.emit 'new',
    room: 'top'
  # TODO: remove debug outputs
  console.log('socket connect try')

  socket.on 'move', (data) ->
    if data.pow == 0
      return
    if data.con == Controller.left
      game.walk_player(data.id, data.rad, data.pow)
    else
      game.shot_player(data.id, data.rad, data.pow)

  socket.on 'shake', (data) ->
    game.dash_player(data.id)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)

  socket.on 'createuser', (data) ->
    game.addPlayer(data.id, data.team)

  socket.on 'removeuser', (data) ->
    game.removePlayer(data.id)

class DomManager
  @addPlayerDom: (player) ->
    nameElem = ($ '<div/>').attr(
      user_id: player.id
      class: 'player'
      team: player.team
    )
    nameElem.append(($ '<p/>').addClass('name').html(player.id))
    nameElem.append(($ '<p/>').addClass('hp'))
    nameElem.append(($ '<p/>').addClass('mp'))
    ($ '#players-box').append(nameElem)

  @updatePlayerDom: (player) ->
    pElem = ($ ".player[user_id=#{player.id}]")
    pElem.children('.hp').html("HP: #{player.hp}")
    pElem.children('.mp').html("MP: #{player.mp}")

  @removePlayerDom: (player) ->
    ($ ".player[user_id=#{player.id}]").remove()
