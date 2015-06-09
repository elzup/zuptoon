
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

  sp = 1.0

  player_group = null
  liquid_group = null

  Liquid = enchant.Class.create enchant.Sprite,
    col: 0
    initialize: (x, y, vx, vy, col) ->
      enchant.Sprite.call(this, 16, 16)
      spr_count += 1
      @.image = game.assets['/images/icon0.png']
      @.col = col
      @.moveTo(x + @.width / 2, y + @.height / 2)
      @.frame = 12
      @._style.zIndex = - SPR_Z_SHIFT
      @.tl.moveBy(vx * 30.0, vy * 30.0, 8).then -> @.pop()

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
      @.tl.scaleTo(2.0, 2.0, 10.0)

  col_lib = ['red', 'yellow', 'blue', 'green'];
  Player = enchant.Class.create enchant.Sprite,
    dx: 1
    dy: 0
    col: null
    id: null
    initialize: (id) ->
      enchant.Sprite.call(@, 32, 32)
      @.id = id
      @.frame = [6, 6, 7, 7]
      @.moveTo(game.width / 2 - @.width / 2, game.height / 2 - @.height / 2)
      @.image = game.assets['/images/chara1.png']
      @.frame = 5
      @.col = col_lib[ElzupUtils.rand_range(col_lib.length)]
      console.log(@.col)
      @._style.zIndex = - PLAYER_Z_SHIFT
      player_group.addChild(@)
    doubleshot: ()->
      @.tl.then(-> @.shot()).delay(5).then(-> @.shot())
    shot: ()->
      new Liquid(@.x, @.y, @.dx, @.dy, @.col)
    walk: (dx, dy) ->
      nx = ElzupUtils.clamp(@.x + dx * sp, game.width - @.width)
      ny = ElzupUtils.clamp(@.y + dy * sp, game.height - @.height)
      @.moveTo(nx, ny)
      @.dx = dx
      @.dy = dy
      @.scaleX = if dx > 0 then 1 else -1

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
    player.walk(data.dx, data.dy)
    if data.act? && data.act
      player.shot()

  socket.on 'shake', (data) ->
    player = get_player(data.id)
    if !player?
      return
    player.doubleshot()
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)

  socket.on 'createuser', (data) ->
    console.log('create user')
    console.log(data)
    player = new Player(data.id)
    player_group.addChild(player)

  socket.on 'removeuser', (data) ->
    console.log('delete user')
    console.log(data)
    player = get_player(data.id)
    player_group.removeChild(player)
