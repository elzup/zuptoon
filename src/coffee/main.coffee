
$ ->
  # enchant game
  enchant()
  game = new Core(320, 320)
  game.preload('images/chara1.png')
  game.fps = 20;

  bear = null
  sp = 4.0

  game.onload = ->
    bear = new Sprite(32, 32)
    bear.image = game.assets['images/chara1.png']
    game.rootScene.addChild(bear)
    bear.frame = [6, 6, 7, 7]
    bear.moveTo(game.width / 2 - bear.width / 2, game.height / 2 - bear.height / 2)

  walk = (dx, dy) ->
    bear.moveBy(dx * sp, dy * sp)
    bear.scaleX = if dx > 0 then 1 else -1

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  socket.on 'move', (data) ->
    walk(data.dx, data.dy)
    console.log(data)

  socket.on 'shake', (data) ->
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)
