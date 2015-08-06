# constants
fps = 20

# alias
eu = ElzupUtils
Vector2 = tm.geom.Vector2

# global variables

core = null
game = null

require ['game', 'stage'], (Game, Stage) ->
  Controller =
    left: 0
    right: 1

  # enchant game
  enchant()
  # core setting
  core = new Core(Stage.width, Stage.height)
  core.preload ['/images/player.png'
                '/images/map0.png'
                '/images/hpbar.png'
                '/images/bar_cell.png'
                '/images/item.png']
  core.fps = fps

  # socket io
  socket = io.connect()

  core.onload = ->
    game = new Game(core)
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
