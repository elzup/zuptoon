define ['player', 'stage'], (Player, Stage) ->
  fps = 20
  class Game
    startTme: 0
    _addItemInterval: fps * 20

    constructor: (@core) ->
      @players = {}
      @stage = new Stage(@core)
      @startTime = @core.frame

    onenterframe: ->
      for id, player of @players
        player.onenterframe()
        for idItem, item of @stage.items
          if Game.conflictItem(player, item)
            console.log "conf"
            player.appendItem(item.type)
            @stage.items[idItem].close()
            delete @stage.items[idItem]

      if @age() % @_addItemInterval == 0 and
          Object.keys(@players).length > 0
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

    @conflictItem: (player, item) ->
      r = player.r() + item.r()
      dx = player.pos.x - item.pos.x
      dy = player.pos.y - item.pos.y
      return Math.pow(r, 2) > Math.pow(dx, 2) + Math.pow(dy, 2)

  return Game
