
$ ->
  # enchant game
  enchant()
  game = new Core(320, 320)
  game.preload('images/chara1.png', 'images/icon0.png')
  game.fps = 20;

  sp = 4.0

  player = null
  game.onload = ->
    Liquid = enchant.Class.create enchant.Sprite,
      initialize: ->
        enchant.Sprite.call(this, 16, 16)
        @.image = game.assets['images/icon0.png']
        @.moveTo(player.x, player.y)
        @.frame = 12
        game.rootScene.addChild(@)

    Player = enchant.Class.create enchant.Sprite,
      initialize: ->
        enchant.Sprite.call(@, 32, 32)
        @.frame = [6, 6, 7, 7]
        @.moveTo(game.width / 2 - @.width / 2, game.height / 2 - @.height / 2)
        @.image = game.assets['images/chara1.png']
        @.frame = 5
        game.rootScene.addChild(this)
      splash: ->
        new Liquid()
      walk: (dx, dy) ->
        @.moveBy(dx * sp, dy * sp)
        @.scaleX = if dx > 0 then 1 else -1

    player = new Player()

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  socket.on 'move', (data) ->
    player.walk(data.dx, data.dy)
    console.log(data)

  socket.on 'shake', (data) ->
    player.splash()
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)
