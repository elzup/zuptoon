# constants
fps = 20

# alias
eu = ElzupUtils
Vector2 = tm.geom.Vector2

# global variables

core = null
game = null

getParams = eu.get_parameters()

class Game
  constructor: ->
    @players = {}
    @stage = new Stage()

  onenterframe: ->
    for id, player of @players
      player.onenterframe()

  addPlayer: (id, team, ua) ->
    player = new Player(id, team, ua)
    @players[id] = player
    console.log 'add:', @players

  removePlayer: (id) ->
    if !@players[id]?
      return
    @players[id].close()
    delete @players[id]
    console.log 'remove:', @players

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

  @cellSize = 8
  @widthN = 64 * 2
  @heightN = 48 * 2
  @width = Stage.widthN * Stage.cellSize
  @height = Stage.heightN * Stage.cellSize

  @widthTopN = 0
  @widthEndN = Stage.widthN - 1
  @heightTopN = 0
  @heightEndN = Stage.heightN - 1

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
    new Vector2(Stage.widthN / 7, Stage.heightN / 10)
    new Vector2(Stage.widthN * 6 / 7, Stage.heightN / 10)
    new Vector2(Stage.widthN / 7, Stage.heightN * 6 / 10)
    new Vector2(Stage.widthN * 6 / 7, Stage.heightN * 9 / 10)
  ]

  @widthEnds: () ->
    [Stage.widthEndN, Stage.widthTopN]

  @heightEnds: () ->
    [Stage.heightEndN, Stage.heightTopN]

  constructor: ->
    @map = new Map(Stage.cellSize, Stage.cellSize)
    @map.image = core.assets['/images/map0.png']
    core.rootScene.addChild(@map)
    @setupMap()

  setupMap: ->
    # 指定があればステージタイプを決める
    if getParams.type
      stageType = parseInt(getParams.type)
    else
      stageType = Stage.type.blocks
    if stageType in [Stage.type.flat, Stage.type.blocks]
      @baseMap = [0...Stage.heightN]
      for j in @baseMap
        @baseMap[j] = [0...Stage.widthN]
        for i in @baseMap[j]
          @baseMap[j][i] = 0
          span = 30
          col = 5
          padding = 5
          if stageType == Stage.type.blocks and
              padding < j < (Stage.heightN - padding) and
              padding < i < (Stage.widthN - padding) and
              (i + 15) % span < col and
              (j + 15) % span < col
            @baseMap[j][i] = Stage.blockType.block
          if j in Stage.heightEnds() or i in Stage.widthEnds()
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
        for j in [0...Stage.heightN]
          for i in [0...Stage.widthN]
            p = @baseMap[j][i]
            if not Stage.isBlock(p) and p != Stage.blockType.none
              Stage.initPos[p - 1] = new Vector2(i, j)
        @map.loadData(@baseMap)
        console.log "map loaded"


  @isBlock: (type) ->
    type in Stage.wall()

  @toMpos: (spos, r = 0) ->
    [Stage.toMx(spos.x + r), Stage.toMy(spos.y + r)]

  @toMx: (sx) ->
    eu.clamp(Math.floor(sx / Stage.cellSize), Stage.widthN - 1)

  @toMy: (sy) ->
    eu.clamp(Math.floor(sy / Stage.cellSize), Stage.heightN - 1)

  @toSpos: (mx, my) ->
    new Vector2(Stage.toSx(mx), Stage.toSy(my))

  @toSx: (mx) ->
    Stage.cellSize * mx

  @toSy: (my) ->
    Stage.cellSize * my


  mapType: (spos) ->
    [mx, my] = Stage.toMpos(spos)
    @baseMap[my][mx]

  @wall: ->
    [Stage.blockType.block, Stage.blockType.wall]

  @noFill: ->
    [Stage.blockType.block, Stage.blockType.wall, Stage.blockType.mp]

  fillMp: (ox, oy, mp) ->
    k = 0
    # 中央から外側に向けて塗りつぶす
    while true
      msy = eu.clamp(oy - k, Stage.heightN - 1, 0)
      mey = eu.clamp(oy + k, Stage.heightN - 1, 0)
      msx = eu.clamp(ox - k, Stage.widthN - 1, 0)
      mex = eu.clamp(ox + k, Stage.widthN - 1, 0)
      kk = Math.pow(k, 2)
      for my in [msy..mey]
        for mx in [msx..mex]
          dx = ox - mx
          dy = oy - my
          # 円形に塗りつぶす
          if mp <= 0 or kk < dx * dx + dy * dy
            continue
          type = @baseMap[my][mx]
          if type in Stage.noFill()
            continue
          @baseMap[my][mx] = Stage.blockType.mp
          mp -= 1
      k += 1
      if k > Stage.heightN
        break
      if mp <= 0
        break
    @map.loadData(@baseMap)

class Player
  id: null
  pos: Vector2.ZERO.clone()
  v: Vector2.ZERO.clone()
  a: new Vector2(0.8, 0.8)
  prePos: Vector2.ZERO.clone()
  team: 0
  col: null
  isDie: false
  mp: 160
  hp: 16
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

  # ua は別処理のが理想的
  constructor: (@id, @team, @ua) ->
    @s = new Sprite(32, 32)
    @pos = Stage.initPos[@team].clone().mul(Stage.cellSize)
    @pos.sub(new Vector2(@r(), @r()))
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
    # back = new Sprite(32, 8)
    # back.image = core.assets['/images/hpbar.png']
    # bar.addChild(back)
    @updateBar(bar, bar.num, frame)
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
    # hard code for mp range
    mpPre = parseInt(@mp / 10)
    @mp += diff
    if @mp < 0
      diff -= @mp
      @mp = 0
    mpNow = parseInt(@mp / 10)
    d = mpNow - mpPre
    if d != 0
      @updateBar(@sMpBar, d, Player.barType.mp)
    diff

  updateBar: (bar, diff, frame = Player.barType.hp) ->
    if diff == 0
      return
    bar.num += diff
    if diff > 0
      for i in [0...diff]
        scale = new Sprite(2, 8)
        scale.image = core.assets['/images/bar_cell.png']
        scale.frame = frame
        scale.x = 2 * (bar.childNodes.length - 1)
        bar.addChild(scale)
      return
    for i in [0...diff]
      bar.removeChild(bar.lastChild)

  close: ->
    DomManager.removePlayerDom(this)
    core.rootScene.removeChild(@sHpBar)
    core.rootScene.removeChild(@sMpBar)
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
    pmp = -@updateMp(-10)
    # mr = @pow / 90 * 10
    v = new Vector2(0, -1).setRadian(Math.PI / 2 - @rad).normalize().mul(10)
    @preShotAge = @s.age

    pos = @pos.clone().add(v.clone().mul(3))
    # un save instance
    new Shot(pos, v, @team, pmp)
    @s.rotation = 180 - @rad * 180 / Math.PI
    DomManager.updatePlayerDom(this)

  walk: (@rad, @pow) ->
    mr = @pow / 90 * 2
    va = new Vector2.LEFT.clone().setRadian(Math.PI / 2 - @rad).mul(mr)
    @v.add va
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
    @prePos = @pos.clone()

    if @isDie
      return
    if @v.length() == 0
      return

    @safeMove()
    @recoverMapMP()
    @v.set(@v.x * @a.x, @v.y * @a.y)
    if @v.length() < 0.5
      @v = Vector2.ZERO.clone()
    @move()

  safeMove: ->
    vx = @v.x
    vy = @v.y
    k = @v.clone()

    dx = Math.abs(vx)
    dy = Math.abs(vy)
    cposs = []
    for deg in [0...360] by 30
      rad = deg * Math.PI * 2 / 360
      basev = new Vector2(Math.cos(rad), Math.sin(rad))
      cposs.push(basev.mul(@r()).add(@oPos()))

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
        if Stage.isBlock(game.stage.baseMap[my][mx])
          tsx = Stage.toSx(mx)
          k.x = 0
          if @v.x >= 0
            vxt = tsx - p.x
          else
            vxt = p.x - (tsx + Stage.cellSize)
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
        if Stage.isBlock(game.stage.baseMap[my][mx])
          tsy = Stage.toSy(my)
          k.y = 0
          if @v.y >= 0
            vyt = tsy - p.y
          else
            vyt = p.y - (tsy + Stage.cellSize)
          vyt -= 5
          break
      dy = Math.min(dy, vyt)

    if vy < 0
      dy *= -1

    @pos.y += dy
    @v = k

  recoverMapMP: ->
    [@msx, @msy] = Stage.toMpos(@pos)
    [@mex, @mey] = Stage.toMpos(new Vector2(@pos.x + @width, @pos.y + @height))
    cmp = 0
    for my in [@msy..@mey]
      for mx in [@msx..@mex]
        if game.stage.baseMap[my][mx] == Stage.blockType.mp
          game.stage.baseMap[my][mx] = Stage.blockType.none
          cmp += 1
    DomManager.updatePlayerDom(this)
    game.stage.map.loadData(game.stage.baseMap)
    if cmp > 0
      @updateMp(cmp)

  moved: ->
    @v.length() != 0

  die: ->
    console.log 'die'
    @s.opacity = 0.5
    @v = Vector2.ZERO.clone()
    @isDie = true
    [mx, my] = Stage.toMpos(@oPos())
    game.stage.fillMp(mx, my, @mp)
    @updateMp(- @mp)
    # @s.frame = frame.none
    # @diemove()

  diemove: ->
    @s.tl.clear()
    @s.tl.moveTo(Stage.initPos[@team].x * Stage.cellSize,
                      Stage.initPos[@team].y * Stage.cellSize,
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
    new Vector2(@oX(), @oY())

class Shot
  pos: Vector2.ZERO.clone()
  v: Vector2.ZERO.clone()
  a: new Vector2(1.0, 1.0)
  width: 16
  height: 16

  @frame:
    none: -1
    itemShot: 2

  constructor: (@pos, @v, @team, @mp) ->
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

    if @s.age > 20 and @s.age % 3 and @mp > 0
      [mx, my] = Stage.toMpos(@oPos())
      if game.stage.baseMap[my][mx] not in Stage.noFill()
        game.stage.baseMap[my][mx] = Stage.blockType.mp
        game.stage.map.loadData(game.stage.baseMap)
        @mp -= 1

    # ブロック衝突判定

    if Stage.isBlock(game.stage.mapType(@oPos()))
      @die()

    # プレイヤー衝突判定
    for id, player of game.players
      if player.team == @team || player.isDie
        continue
      dx = player.oX() - @oX()
      dy = player.oY() - @oY()
      if dx * dx + dy * dy < Math.pow((@width / 2 + player.width) / 2, 2)
        player.v.add(@v.mul(3.0))
        @die()
        player.damage()
        return

  die: ->
    [mx, my] = Stage.toMpos(@oPos())
    game.stage.fillMp(mx, my, @mp)
    core.rootScene.removeChild(@s)

  move: (x = @pos.x, y = @pos.y) ->
    @s.moveTo(x, y)

  r: ->
    @width / 2
  oX: ->
    @pos.x + @width / 2
  oY: ->
    @pos.y + @height / 2
  oPos: ->
    new Vector2(@oX(), @oY())

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
  core = new Core(Stage.width, Stage.height)
  core.preload ['/images/player.png'
                '/images/icon0.png'
                '/images/map0.png'
                '/images/hpbar.png'
                '/images/bar_cell.png'
                '/images/item.png']
  core.fps = fps

  # socket io
  socket = io.connect()

  core.onload = ->
    game = new Game
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
      console.log "fps:", (fpsAvg / 100).toFixed(2)
      fpss = []
  core.start()

  gameInit = ->
    core.rootScene.remove()
    # player は手前

    core.rootScene.backgroundColor = "#AAA"

  socket.emit 'new',
    room: 'top'
  # TODO: remove debug outputs
  console.log 'socket connect try'

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
    game.addPlayer(data.id, data.team, data.ua)

  socket.on 'removeuser', (data) ->
    console.log 'remove', data
    game.removePlayer(data.id)

class DomManager
  @addPlayerDom: (player) ->
    $playerElem = ($ '<p/>').attr
      user_id: player.id
      class: 'player'
    $i = ($ '<i/>').addClass('fa')
    switch (player.ua)
      when eu.userAgent.android
        $i.addClass('fa-android')
      when eu.userAgent.iphone
        $i.addClass('fa-apple')
      else
        $i.addClass('fa-desktop')
    $delI = ($ '<i/>').addClass('fa fa-minus')
    $delBtn = ($ '<button/>').addClass('del-btn').append($delI)
    $delBtn.click ->
      game.removePlayer(player.id)
    $playerElem.append($i)
    $name = ($ '<span/>').addClass('name').html(player.id.substr(0, 8))
    $playerElem.append($i).append($name).append($delBtn)
    ($ ".team-box[team=#{player.team}]").append($playerElem)

  @updatePlayerDom: (player) ->
    pElem = ($ ".player[user_id=#{player.id}]")

  @removePlayerDom: (player) ->
    ($ ".player[user_id=#{player.id}]").remove()
