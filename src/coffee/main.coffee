
$ ->
  # enchant game
  enchant()
  game = new Core(320, 320)
  game.preload('images/chara1.png', 'images/icon0.png')
  game.fps = 20;

  sp = 4.0

  player = null
  game.onload = ->

    # create liquid image
    sfc = new Surface(16, 16)
    ctx = sfc.context
    ctx.beginPath()
    ctx.arc(sfc.width / 2, sfc.height / 2, sfc.width / 2, 0, Math.PI * 2, false)
    ctx.fillStyle = 'green'
    ctx.fill()

    spr_count = 0
    SPR_Z_SHIFT = 1000
    PLAYER_Z_SHIFT = 10000

    Liquid = enchant.Class.create enchant.Sprite,
      initialize: (vx, vy) ->
        enchant.Sprite.call(this, 16, 16)
        spr_count += 1
        @.image = game.assets['images/icon0.png']
        @.moveTo(player.x + @.width / 2, player.y + @.height / 2)
        @.frame = 12
        @._style.zIndex = - SPR_Z_SHIFT
        @.tl.moveBy(vx * 30.0, vy * 30.0, 8).then -> @.pop()

        liquid_group.addChild(@)
      pop: ->
        @.scale(2.0, 2.0)
        @.image = sfc
        @.tl.scaleTo(2.0, 2.0, 10.0)

    Player = enchant.Class.create enchant.Sprite,
      dx: 1
      dy: 0
      initialize: ->
        enchant.Sprite.call(@, 32, 32)
        @.frame = [6, 6, 7, 7]
        @.moveTo(game.width / 2 - @.width / 2, game.height / 2 - @.height / 2)
        @.image = game.assets['images/chara1.png']
        @.frame = 5
        @._style.zIndex = - PLAYER_Z_SHIFT
        player_group.addChild(@)
      doubleshot: ()->
        @.tl.then(-> @.shot()).delay(5).then(-> @.shot())
      shot: ()->
        new Liquid(@.dx, @.dy)
      walk: (dx, dy) ->
        @.moveBy(dx * sp, dy * sp)
        @.dx = dx
        @.dy = dy
        @.scaleX = if dx > 0 then 1 else -1

    player_group = new Group()
    liquid_group = new Group()
    # player は手前
    game.rootScene.addChild(liquid_group)
    game.rootScene.addChild(player_group)
    player = new Player()

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  socket.on 'move', (data) ->
    player.walk(data.dx, data.dy)
    console.log(data)

  socket.on 'shake', (data) ->
    player.doubleshot()
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)
