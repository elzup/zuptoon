define ['player', 'stage'], (Player, Stage) ->
  fps = 20
  class Game
    startTme: 0

    _addItemInterval: fps * 5

    constructor: (@core) ->
      @players = {}
      @stage = new Stage(@core)
      @startTime = @core.frame

    onenterframe: ->
      for id, player of @players
        player.onenterframe()
      # TODO: player > 0
      if @age() % @_addItemInterval == 0
        @stage.inclementItem()

    age: ->
      @core.frame - @startTime

    addPlayer: (id, team, ua) ->
      player = new Player(id, team, ua, @core, this)
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

  return Game
