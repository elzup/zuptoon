
$ ->
  # enchant game
  enchant()
  game = new Core(320, 320)
  game.preload('images/chara1.png')
  game.fps = 20;

  game.onload = ->
    bear = new Sprite(32, 32)
    bear.image = game.assets['images/chara1.png']
    game.rootScene.addChild(bear)
    bear.frame = [6, 6, 7, 7]

    bear.tl.moveBy(288, 0, 90)
      .scaleTo(-1, 1, 10)
      .moveBy(-288, 0, 90)
      .scaleTo(1, 1, 10)
      .loop()

  game.start()

  # socket io
  socket_url = 'http://192.168.1.50'
  socket = io.connect socket_url

  socket.on 'pyon', (data) ->
    console.log(data)

  socket.on 'count', (data) ->
    $count = $('#count')
    $count.text(data.count)
    console.log(data)
