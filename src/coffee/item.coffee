define ->
  # remove global
  fps = 20
  eu = ElzupUtils
  Vector2 = tm.geom.Vector2

  class Item
    @type:
      monopoly: 6
      lifeUp: 7
    width: 32
    height: 32

    # remove @pos
    constructor: (@mx, @my, @type, @core, @game, @pos) ->
      @s = new Sprite(@width, @height)
      @pos.sub(new Vector2(@r(), @r()))
      @s.image = @core.assets['/images/item.png']
      @s.frame = @type
      @s.moveTo(@pos.x, @pos.y)
      @core.rootScene.addChild(@s)

    @getRandomType: ->
      arr = []
      arr.push val for key, val of Item.type
      return arr[Math.floor(Math.random() * arr.length)]

    @posEquals: (item) ->
      @mx == item.mx && @my == item.my

    close: ->
      @core.rootScene.removeChild(@s)

    r: ->
      @width / 2
    oX: ->
      @pos.x + @width / 2
    oY: ->
      @pos.y + @height / 2
    oPos: ->
      new Vector2(@oX(), @oY())
    ePos: ->
      new Vector2(@pos.x + @width, @pos.y + @height)
  return Item
