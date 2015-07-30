# constants
fps = 20

mapM = 8
mapWidthN = 64 * 2
mapHeightN = 48 * 2
mapWidth = mapWidthN * mapM
mapHeight = mapHeightN * mapM
mapMVec = new Victor(mapM, mapM)

# global variables

core = null
game = null

zerovic = ->
  new Victor(0, 0)

clone = (v) ->
  new Victor(0, 0).copy(v)

print = (params...) ->
  if params.length == 1
    console.log params[0]
  else if params.length == 2
    console.log params[0], params[1]
  else if params.length == 3
    console.log params[0], params[1], params[2]
  else
    console.log params

# alias
eu = ElzupUtils
getParams = eu.get_parameters()

debugSurface = null

toXY = (rad) ->
  new Victor(Math.cos(rad), Math.sin(rad))

gameTimeLimitSec = 90
gameTimePreFinish = parseInt(gameTimeLimitSec / 6)
footerHeight = 80

term =
  ready: 0
  progress: 1
  result: 2

class Game
  constructor: ->
    @players = {}
    @setupMap()

  onenterframe: ->
    for id, player of @players
      player.onenterframe()

  addPlayer: (id, team) ->
    player = new Player(id, team)
    @players[id] = player
    console.log 'add:', @players

  removePlayer: (id) ->
    if !@players[id]?
      return
    @players[id].close()
    delete @players[id]
    console.log 'remove:', @players

  setupMap: ->
    @map = new Map(mapM, mapM)
    @map.image = core.assets['/images/map0.png']
    core.rootScene.addChild(@map)
    if stageType in [Stage.type.flat, Stage.type.blocks]
      @baseMap = [0...mapHeightN]
      for j in @baseMap
        @baseMap[j] = [0...mapWidthN]
        for i in @baseMap[j]
          @baseMap[j][i] = 0
          span = 30
          col = 5
          padding = 5
          if stageType == Stage.type.blocks and
              padding < j < (mapHeightN - padding) and
              padding < i < (mapWidthN - padding) and
              (i + 15) % span < col and
              (j + 15) % span < col
            @baseMap[j][i] = Stage.blockType.block
          if j == 0 or j == mapHeightN - 1 or i == 0 or i == mapWidthN - 1
            @baseMap[j][i] = Stage.blockType.wall
      @map.loadData(@baseMap)
    else
      if stageType == Stage.type.wall
        filename = "/data/map_wall.json"
      else if stageType == Stage.type.vortex
        filename = "/data/map_vortex.json"
      else
        filename = "/data/map_sprite.json"
      $.getJSON filename, (data) =>
        @baseMap = data
        for j in [0...mapHeightN]
          for i in [0...mapWidthN]
            p = @baseMap[j][i]
            if not Stage.isBlock(p) and p != Stage.blockType.none
              Stage.initPos[p - 1] = new Victor(i, j)
        @map.loadData(@baseMap)
        print "map loaded"

  walkPlayer: (id, rad, pow) ->
    if !@players[id]?
      return
    @players[id].walk(rad, pow)

  dashPlayer: (id) ->
    if !@players[id]?
      return
    @players[id].dash()

  shotPlayer: (id, rad, pow) ->
    if !@players[id]?
      return
    @players[id].shot(rad, pow)

class Stage
  @type:
    flat: 0
    blocks: 1
    wall: 2
    vortex: 3
    sprite: 4

  @blockType:
    none: 0
    mp: 9
    block: 5
    wall: 6

  @initPos = [
    new Victor(mapWidthN / 7, mapHeightN / 10)
    new Victor(mapWidthN * 6 / 7, mapHeightN / 10)
    new Victor(mapWidthN / 7, mapHeightN * 6 / 10)
    new Victor(mapWidthN * 6 / 7, mapHeightN * 9 / 10)
  ]


  @isBlock: (type) ->
    type in [Stage.blockType.block, Stage.blockType.wall]

  @toMpos = (spos, r = 0) ->
    [Stage.toMx(spos.x + r), Stage.toMy(spos.y + r)]

  @toMx = (sx) ->
    eu.clamp(Math.floor(sx / mapM), mapWidthN - 1)

  @toMy = (sy) ->
    eu.clamp(Math.floor(sy / mapM), mapHeightN - 1)

  @toSpos = (mx, my) ->
    new Victor(Stage.toSx(mx), Stage.toSy(my))

  @toSx = (mx) ->
    mapM * mx

  @toSy = (my) ->
    mapM * my

  @mapType = (spos) ->
    [mx, my] = Stage.toMpos(spos)
    game.baseMap[my][mx]


class Player
  id: null
  pos: zerovic()
  v: zerovic()
  a: new Victor(0.8, 0.8)
  prePos: zerovic()
  team: 0
  col: null
  isDie: false
  mp: 16
  hp: 8
  pointer: null
  preShotAge: 0
  width: 32
  height: 32
  @color = ['red', 'yellow', 'blue', 'green']

  # ショット後のデュレイ
  @shotRapidDelay = fps * 0.2
  # 重なり順序優先度
  @zShift = 10000

  @frame:
    none: -1
    stand: 0
    walk: 1
    attack: 2
    damage: 3
    super: 4

  constructor: (@id, @team) ->
    @s = new Sprite(32, 32)
    @pos = clone(Stage.initPos[@team]).multiply(mapMVec)
    @pos.subtract(new Victor(@r(), @r()))
    @move()
    @s.image = core.assets['/images/player.png']
    @s.frame = @team * 5
    @col = Player.color[@team]
    @s._style.zIndex = -@zShift
    DomManager.addPlayerDom(this)
    DomManager.updatePlayerDom(this)
    core.rootScene.addChild(@s)
    @setupBars()

  @barType:
    hp: 0
    mp: 1

  setupBars: ->
    @sHpBar = @createBar(Player.barType.hp)
    @sMpBar = @createBar(Player.barType.mp)

  createBar: (frame = Player.barType.hp) ->
    bar = new Group()
    bar.num = 16
    back = new Sprite(32, 8)
    back.image = core.assets['/images/hpbar.png']
    bar.addChild(back)
    @updateBar(bar, 16, frame)
    core.rootScene.addChild(bar)
    heightShift = 5
    if frame == Player.barType.mp
      heightShift = 10
    bar.moveTo(@pos.x, @pos.y + @height + heightShift)
    return bar

  updateHp: (diff) ->
    @updateBar(@sHpBar, diff, Player.barType.hp)
    @hp += diff

  updateMp: (diff) ->
    @updateBar(@sMpBar, diff, Player.barType.mp)
    @mp += diff

  updateBar: (bar, diff, frame = Player.barType.hp) ->
    if diff == 0
      return
    if diff > 0
      for i in [0...bar.num]
        scale = new Sprite(2, 8)
        scale.image = core.assets['/images/bar_cell.png']
        scale.frame = frame
        scale.x = bar.x + 2 * i
        bar.addChild(scale)
      return
    for i in [0...diff]
      bar.removeChild(bar.lastChild)

  close: ->
    DomManager.removePlayerDom(this)
    core.rootScene.removeChild(@s)

  damage: ->
    @updateHp(-2)
    if @hp <= 0
      @die()
    DomManager.updatePlayerDom(this)

  isShotable: ->
    @preShotAge + Player.shotRapidDelay < @s.age

  shot: (@rad, @pow)->
    if @mp == 0 or @isDie or not @isShotable()
      return
    @updateMp(-1)
    # mr = @pow / 90 * 10
    mr = 10
    v = new Victor(0, 1).rotate(-@rad).normalize().multiply new Victor(mr, mr)
    @preShotAge = @s.age

    pos = clone(@pos).add(clone(v).multiply(new Victor(3, 3)))
    # un save instance
    new Shot(pos, v, @team)
    @s.rotation = 180 - @rad * 180 / Math.PI
    DomManager.updatePlayerDom(this)

  walk: (@rad, @pow) ->
    mr = @pow / 90
    @v.add new Victor(0, 2).rotate(-@rad).multiply(new Victor(mr, mr))
    if @isShotable()
      @s.rotation = 180 - @rad * 180 / Math.PI

  move: (x = @pos.x, y = @pos.y) ->
    @s.moveTo(x, y)
    if @sHpBar?
      @sHpBar.moveTo(x, y + @height + 5)
    if @sMpBar?
      @sMpBar.moveTo(x, y + @height + 10)

  dash: ->
    @walk(@direRadV(), 1000)

  direRad: ->
    (1 - @s.rotation / 180) * Math.PI

  direRadV: ->
    Math.atan2(@v.x, @v.y)

  onenterframe: ->
    if @moved()
      f = [Player.frame.walk, Player.frame.stand][eu.period(@s.age, 8, 2)]
      @s.frame = @team * 5 + f
    else
      @s.frame = @team * 5 + Player.frame.stand
    @prePos.copy(@pos)

    if @isDie
      return
    if @v.length() == 0
      return

    @safeMove()
    @recoverMapMP()
    @v.multiply(@a)
    if @v.length() < 0.5
      @v = zerovic()
    @move()

  safeMove: ->
    vx = @v.x
    vy = @v.y
    k = clone(@v)

    dx = Math.abs(vx)
    dy = Math.abs(vy)
    cposs = []
    for deg in [0...360] by 30
      rad = deg * Math.PI * 2 / 360
      cposs.push(toXY(rad).multiply(new Victor(@r(), @r())).add(@oPos()))

    for p in cposs
      tx = p.x + @v.x
      # mx, my 単体取得
      [msx, my] = Stage.toMpos(p)
      mex = Stage.toMx(tx)
      vxt = Math.abs vx
      msx += 1
      if @v.x < 0
        msx -= 2
      for mx in [msx..mex]
        if game.baseMap[my][mx] in [Stage.blockType.block, Stage.blockType.wall]
          tsx = Stage.toSx(mx)
          k.x = 0
          if @v.x >= 0
            vxt = tsx - p.x
          else
            vxt = p.x - (tsx + mapM)
          vxt -= 5
          break
      dx = Math.min(dx, vxt)

    if vx < 0
      dx *= -1
    @pos.x += dx

    for p in cposs
      ty = p.y + @v.y
      p.x += dx
      [mx, msy] = Stage.toMpos(p)
      mey = Stage.toMy(ty)
      vyt = Math.abs vy
      msy += 1
      if @v.y < 0
        msy -= 2
      for my in [msy..mey]
        if game.baseMap[my][mx] in [Stage.blockType.block, Stage.blockType.wall]
          tsy = Stage.toSy(my)
          k.y = 0
          if @v.y >= 0
            vyt = tsy - p.y
          else
            vyt = p.y - (tsy + mapM)
          vyt -= 5
          break
      dy = Math.min(dy, vyt)

    if vy < 0
      dy *= -1

    @pos.y += dy
    @v = k

  recoverMapMP: ->
    [@msx, @msy] = Stage.toMpos(@pos)
    [@mex, @mey] = Stage.toMpos(new Victor(@pos.x + @width, @pos.y + @height))
    cmp = 0
    for my in [@msy..@mey]
      for mx in [@msx..@mex]
        if game.baseMap[my][mx] == Stage.blockType.mp
          game.baseMap[my][mx] = Stage.blockType.none
          cmp += 1
    DomManager.updatePlayerDom(this)
    @updateMp(cmp)

  moved: ->
    @v.length() != 0

  die: ->
    print('die')
    @s.opacity = 0.5
    @v = zerovic()
    @isDie = true
    # @s.frame = frame.none
    # @diemove()

  diemove: ->
    @s.tl.clear()
    @s.tl.moveTo(Stage.initPos[@team].x * mapM,
                      Stage.initPos[@team].y * mapM,
                      fps / 2)
    .delay(fps).and().repeat(->
      @s.opacity = @s.age % 2
    , fps).then(->
      @s.opacity = 1.0
      @isDie = false
    )

  r: ->
    @width / 2
  oX: ->
    @pos.x + @width / 2
  oY: ->
    @pos.y + @height / 2
  oPos: ->
    new Victor(@oX(), @oY())

class Shot
  pos: zerovic()
  v: zerovic()
  a: new Victor(1.0, 1.0)
  mp: 5
  width: 16
  height: 16

  @frame:
    none: -1
    itemShot: 2

  constructor: (@pos, @v, @team) ->
    @s = new Sprite(32, 32)
    @s.image = core.assets['/images/item.png']
    @s.frame = Shot.frame.itemShot
    @move()
    @s.tl.scaleTo(0.5, 0.5)
    rad = Math.atan2(@v.x, @v.y)
    @s.rotation = 180 - rad * 180 / Math.PI
    @s.addEventListener Event.ENTER_FRAME, =>
      @onenterframe()
    core.rootScene.addChild(@s)

  onenterframe: ->
    @pos.add(@v)
    @move()
    # @v.multiply(@a)

    # ブロック衝突判定
    if Stage.mapType(@oPos()) in [Stage.blockType.block, Stage.blockType.wall]
      core.rootScene.removeChild(@s)

    # mp の分布変更
    if @s.age % 10 == 0
      [mx, my] = Stage.toMpos(@oPos())
      if game.baseMap[my][mx] not in
          [Stage.blockType.wall, Stage.blockType.wall]
        game.baseMap[my][mx] = Stage.blockType.mp
        game.map.loadData(game.baseMap)
        @mp -= 1

    # プレイヤー衝突判定
    for id, player of game.players
      if player.team == @team || player.isDie
        continue
      dx = player.oY() - @oY()
      dy = player.oY() - @oY()
      if dx * dx + dy * dy < Math.pow((@width / 2 + player.width) / 2, 2)
        player.v.add(@v.multiply(new Victor(3.0, 3.0)))
        core.rootScene.removeChild(@s)
        player.damage()
        return

  move: (x = @pos.x, y = @pos.y) ->
    @s.moveTo(x, y)

  r: ->
    @width / 2
  oX: ->
    @pos.x + @width / 2
  oY: ->
    @pos.y + @height / 2
  oPos: ->
    new Victor(@oX(), @oY())

# 指定があればステージタイプを決める
if getParams['type'] ?
  stageType = getParams['type']
else
  stageType = Stage.type.blocks
# [0, 2, 3, 4][Math.floor(Math.random() * 4)]


$ ->
  Controller =
    left: 0
    right: 1

  gameFont = '50px "ヒラギノ角ゴ ProN W3",
   "Hiragino Kaku Gothic ProN", "メイリオ", Meiryo, sans-serif'


  # enchant game
  enchant()
  # core setting
  core = new Core(mapWidth, mapHeight + footerHeight)
  core.preload ['/images/player.png'
                '/images/icon0.png'
                '/images/map0.png'
                '/images/hpbar.png'
                '/images/bar_cell.png'
                '/images/item.png']
  core.fps = fps

  # global
  # NOTE: term 言い回しは正当？
  term = null

  timerLabel = null
  scoreBar = null
  scoreCover = null
  score = null

  startTime = 0

  # socket io
  socket = io.connect()

  core.onload = ->
    game = new Game

    ### debug init ###
    sp = new Sprite(2000, 2000)
    debugSurface = new Surface(2000, 2000)
    sp.image = debugSurface
    core.rootScene.addChild(sp)
    gameInit()

  oldTime = new Date
  fpss = []
  core.onenterframe = ->
    if game is null
      return
    game.onenterframe()
    newTime = new Date
    fps = 1000 / (newTime.getTime() - oldTime.getTime())
    oldTime = newTime
    fpss.push(fps)
    if fpss.length == 100
      # sum
      fpsAvg = fpss.reduce (x, y) -> x + y
      print "fps:", (fpsAvg / 100).toFixed(2)
      fpss = []
  core.start()

  gameInit = ->
    core.rootScene.remove()
    term = term.ready
    # player は手前

    timerLabel = new Label()
    timerLabel.moveTo(mapWidth / 2 - 20, mapHeight + 10)
    timerLabel.font = gameFont
    timerLabel.addEventListener Event.ENTER_FRAME, ->
      if term != term.progress
        return
      progress = parseInt((core.frame - startTime) / core.fps)
      time = gameTimeLimitSec - progress
      @text = time + ""
      if (time == gameTimePreFinish)
        scoreCover.tl.scaleTo(1.0, 1.0, fps * gameTimePreFinish)
        .delay(fps).scaleTo(0, 1.0, fps * 3).then ->
          core.rootScene.removeChild(@)

      if (time == 0)
        gameResult()

    scoreBar = new Sprite(mapWidth, footerHeight)
    scoreBar.image = new Surface(mapWidth, footerHeight)
    scoreBar.moveTo(0, mapHeight)

    scoreCover = new Sprite(mapWidth * 0.5, footerHeight)
    scoreCover.backgroundColor = "gray"
    scoreCover.scale(0, 1.0)
    scoreCover.moveTo(mapWidth * 0.75, mapHeight)

    score = [0, 0, 0, 0]

    btn = new Button("Start")
    margin = 20
    btn.moveTo(margin, mapHeight + margin)
    btn.ontouchstart = ->
      core.rootScene.removeChild(@)
      gameStart()

    core.rootScene.backgroundColor = "#AAA"
    core.rootScene.addChild(scoreBar)
    core.rootScene.addChild(scoreCover)
    core.rootScene.addChild(btn)
    core.rootScene.addChild(timerLabel)

  gameStart = ->
    term = term.progress
    startTime = core.frame

  gameResult = ->
    term = term.result

    btn = new Button("Ready")
    margin = 20
    btn.moveTo(margin, mapHeight + margin)
    btn.ontouchstart = ->
      core.rootScene.removeChild(@)
      gameInit()
    core.rootScene.addChild(btn)

  socket.emit 'new',
    room: 'top'
  # TODO: remove debug outputs
  print 'socket connect try'

  socket.on 'move', (data) ->
    if data.pow == 0
      return
    if data.con == Controller.left
      game.walkPlayer(data.id, data.rad, data.pow)
    else
      game.shotPlayer(data.id, data.rad, data.pow)

  socket.on 'shake', (data) ->
    game.dashPlayer(data.id)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)

  socket.on 'createuser', (data) ->
    game.addPlayer(data.id, data.team)

  socket.on 'removeuser', (data) ->
    console.log 'remove', data
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
