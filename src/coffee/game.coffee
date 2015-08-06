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
        # player - item 衝突チェック
        for idItem, item of @stage.items
          if Game.conflictElems(player, item)
            console.log "conf"
            player.appendItem(item.type)
            @stage.items[idItem].close()
            delete @stage.items[idItem]

        # player - shot 衝突チェック
        for id, shot of @stage.shots
          if player.team == shot.team || player.isDie
            continue
          if Game.conflictElems(player, shot)
            player.v.add(shot.v.mul(3.0))
            shot.die()
            player.damage()
            delete @stage.shots[id]
            continue

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

    @conflictElems: (elem1, elem2) ->
      Game.conflictCircle(elem1.oPos(), elem1.r(), elem2.oPos(), elem2.r())

    @conflictCircle: (pos1, r1, pos2, r2) ->
      r = r1 + r2
      dx = pos1.x - pos2.x
      dy = pos1.y - pos2.y
      Math.pow(r, 2) >= Math.pow(dx, 2) + Math.pow(dy, 2)

  return Game
