define ->
  fps = 20
  Vector2 = tm.geom.Vector2
  class Shot
    pos: Vector2.ZERO.clone()
    v: Vector2.ZERO.clone()
    a: new Vector2(1.0, 1.0)
    width: 16
    height: 16

    @frame:
      none: -1
      itemShot: 2

    constructor: (@pos, @v, @team, @mp) ->
      @s = new Sprite(32, 32)
      @s.image = core.assets['/images/item.png']
      @s.frame = Shot.frame.itemShot
      @move()
      @s.tl.scaleTo(0.5, 0.5)
      rad = Math.atan2(@v.x, @v.y)
      @s.rotation = 180 - rad * 180 / Math.PI
      @s.addEventListener Event.ENTER_FRAME, =>
        @onenterframe()
      core.rootScene.addChild(@s)

    onenterframe: ->
      @pos.add(@v)
      @move()

      if @s.age > 20 and @s.age % 3 and @mp > 0
        [mx, my] = Stage.toMpos(@oPos())
        if game.stage.baseMap[my][mx] not in Stage.noFill()
          game.stage.baseMap[my][mx] = Stage.blockType.mp
          game.stage.map.loadData(game.stage.baseMap)
          @mp -= 1

      # ブロック衝突判定

      if Stage.isBlock(game.stage.mapType(@oPos()))
        @die()

      # プレイヤー衝突判定
      for id, player of game.players
        if player.team == @team || player.isDie
          continue
        dx = player.oX() - @oX()
        dy = player.oY() - @oY()
        if dx * dx + dy * dy < Math.pow((@width / 2 + player.width) / 2, 2)
          player.v.add(@v.mul(3.0))
          @die()
          player.damage()
          return

    die: ->
      [mx, my] = Stage.toMpos(@oPos())
      game.stage.fillMp(mx, my, @mp)
      core.rootScene.removeChild(@s)

    move: (x = @pos.x, y = @pos.y) ->
      @s.moveTo(x, y)

    r: ->
    @width / 2
    oX: ->
      @pos.x + @width / 2
    oY: ->
      @pos.y + @height / 2
    oPos: ->
      new Vector2(@oX(), @oY())
  return Shot

