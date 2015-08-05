define ->
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
  return Game
