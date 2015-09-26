define ['dom_manager', 'shot', 'stage', 'item']
    ,(DomManager, Shot, Stage, Item) ->
  # TODO: remove Stage
  # remove global
  fps = 20
  eu = ElzupUtils
  Vector2 = tm.geom.Vector2
  class Player
    id: null
    pos: Vector2.ZERO.clone()
    v: Vector2.ZERO.clone()
    a: new Vector2(0.8, 0.8)
    prePos: Vector2.ZERO.clone()
    team: 0
    col: null
    isDie: false
    mp: 160
    hp: 16
    pointer: null
    preShotAge: 0
    width: 32
    height: 32
    type: null
    typeTimer: 0
    @color: ['red', 'yellow', 'blue', 'green']

    # ショット後のデュレイ
    @shotRapidDelay: fps * 0.2
    # 重なり順序優先度
    @zShift: 10000

    @frame:
      none: -1
      stand: 0
      walk: 1
      attack: 2
      damage: 3
      super: 4

    # ua は別処理のが理想的
    constructor: (@id, @team, @ua, @core, @game) ->
      @s = new Sprite(32, 32)
      @pos = Stage.initPos[@team].clone().mul(Stage.cellSize)
      @pos.sub(new Vector2(@r(), @r()))
      @move()
      @s.image = @core.assets['/images/player.png']
      @s.frame = @team * 5
      @col = Player.color[@team]
      @s._style.zIndex = -@zShift
      DomManager.addPlayerDom(this)
      DomManager.updatePlayerDom(this)
      @core.rootScene.addChild(@s)
      @setupBars()

    @barType:
      hp: 0
      mp: 1

    setupBars: ->
      @sHpBar = @createBar(Player.barType.hp)
      @sMpBar = @createBar(Player.barType.mp)

    createBar: (frame = Player.barType.hp) ->
      bar = new Group()
      bar.num = 16
      @updateBar(bar, bar.num, frame)
      @core.rootScene.addChild(bar)
      heightShift = 5
      if frame == Player.barType.mp
        heightShift = 10
      bar.moveTo(@pos.x, @pos.y + @height + heightShift)
      return bar

    updateHp: (diff) ->
      @updateBar(@sHpBar, diff, Player.barType.hp)
      @hp += diff

    updateMp: (diff) ->
    # hard code for mp range
      mpPre = parseInt(@mp / 10)
      @mp += diff
      if @mp < 0
        diff -= @mp
        @mp = 0
      mpNow = parseInt(@mp / 10)
      d = mpNow - mpPre
      if d != 0
        @updateBar(@sMpBar, d, Player.barType.mp)
      diff

    updateBar: (bar, diff, frame = Player.barType.hp) ->
      if diff == 0
        return
      bar.num += diff
      if diff > 0
        for i in [0...diff]
          scale = new Sprite(2, 8)
          scale.image = @core.assets['/images/bar_cell.png']
          scale.frame = frame
          scale.x = 2 * (bar.childNodes.length - 1)
          bar.addChild(scale)
        return
      for i in [0...diff]
        bar.removeChild(bar.lastChild)

    close: ->
      DomManager.removePlayerDom(this)
      @core.rootScene.removeChild(@sHpBar)
      @core.rootScene.removeChild(@sMpBar)
      @core.rootScene.removeChild(@s)

    damage: ->
      @updateHp(-2)
      if @hp <= 0
        @die()
      DomManager.updatePlayerDom(this)

    isShotable: ->
      @preShotAge + Player.shotRapidDelay < @s.age

    shot: (@rad, @pow)->
      if @mp == 0 or @isDie or not @isShotable()
        return
      pmp = -@updateMp(-10)
      # mr = @pow / 90 * 10
      v = new Vector2(0, -1).setRadian(Math.PI / 2 - @rad).normalize().mul(10)
      @preShotAge = @s.age

      pos = @pos.clone().add(v.clone().mul(3))
      shot = new Shot(pos, v, @team, pmp, @core, @game)
      @game.stage.addShot(shot)
      @s.rotation = 180 - @rad * 180 / Math.PI
      DomManager.updatePlayerDom(this)

    walk: (@rad, @pow) ->
      mr = @pow / 90 * 2
      va = new Vector2.LEFT.clone().setRadian(Math.PI / 2 - @rad).mul(mr)
      if @isStar()
        va = va.mul(1.5)
      @v.add va
      if @isShotable()
        @s.rotation = 180 - @rad * 180 / Math.PI

    move: (x = @pos.x, y = @pos.y) ->
      @s.moveTo(x, y)
      if @sHpBar?
        @sHpBar.moveTo(x, y + @height + 5)
      if @sMpBar?
        @sMpBar.moveTo(x, y + @height + 10)

    dash: ->
      @walk(@direRadV(), 1000)

    direRad: ->
      (1 - @s.rotation / 180) * Math.PI

    direRadV: ->
      Math.atan2(@v.x, @v.y)

    onenterframe: ->
      if @isStar()
        f = [Player.frame.walk, Player.frame.super][eu.period(@s.age, 4, 2)]
        @s.frame = @team * 5 + f
      else if @moved()
        f = [Player.frame.walk, Player.frame.stand][eu.period(@s.age, 8, 2)]
        @s.frame = @team * 5 + f
      else
        @s.frame = @team * 5 + Player.frame.stand
      @prePos = @pos.clone()

      if @isDie
        return
      if @v.length() == 0
        return

      @safeMove()
      @recoverMapMP()
      @v.set(@v.x * @a.x, @v.y * @a.y)
      if @v.length() < 0.5
        @v = Vector2.ZERO.clone()
      @move()

      # 状態異常の時間切れ確認
      if @typeTimer > 0
        @typeTimer -= 1
        if @typeTimer == 0
          @type = null


    safeMove: ->
      vx = @v.x
      vy = @v.y
      k = @v.clone()

      dx = Math.abs(vx)
      dy = Math.abs(vy)
      cposs = []
      for deg in [0...360] by 30
        rad = deg * Math.PI * 2 / 360
        basev = new Vector2(Math.cos(rad), Math.sin(rad))
        cposs.push(basev.mul(@r()).add(@oPos()))

      for p in cposs
        tx = p.x + @v.x
        # mx, my 単体取得
        [msx, my] = Stage.toMpos(p)
        mex = Stage.toMx(tx)
        vxt = Math.abs vx
        msx += 1
        if @v.x < 0
          msx -= 2
        for mx in [msx..mex]
          if Stage.isBlock(@game.stage.baseMap[my][mx])
            tsx = Stage.toSx(mx)
            k.x = 0
            if @v.x >= 0
              vxt = tsx - p.x
            else
              vxt = p.x - (tsx + Stage.cellSize)
            vxt -= 5
            break
        dx = Math.min(dx, vxt)

      if vx < 0
        dx *= -1
      @pos.x += dx

      for p in cposs
        ty = p.y + @v.y
        p.x += dx
        [mx, msy] = Stage.toMpos(p)
        mey = Stage.toMy(ty)
        vyt = Math.abs vy
        msy += 1
        if @v.y < 0
          msy -= 2
        for my in [msy..mey]
          if Stage.isBlock(@game.stage.baseMap[my][mx])
            tsy = Stage.toSy(my)
            k.y = 0
            if @v.y >= 0
              vyt = tsy - p.y
            else
              vyt = p.y - (tsy + Stage.cellSize)
            vyt -= 5
            break
        dy = Math.min(dy, vyt)

      if vy < 0
        dy *= -1

      @pos.y += dy
      @v = k

    recoverMapMP: ->
      mpSum = @game.stage.popSquareMP(@pos, @ePos())
      DomManager.updatePlayerDom(this)
      if mpSum > 0
        @updateMp(mpSum)

    moved: ->
      @v.length() != 0

    die: ->
      console.log 'die'
      @s.opacity = 0.5
      @v = Vector2.ZERO.clone()
      @isDie = true
      [mx, my] = Stage.toMpos(@oPos())
      @game.stage.fillMp(mx, my, @mp)
      @updateMp(- @mp)
    # @s.frame = frame.none
    # @diemove()

    diemove: ->
      @s.tl.clear()
      @s.tl.moveTo(Stage.initPos[@team].x * Stage.cellSize,
        Stage.initPos[@team].y * Stage.cellSize,
        fps / 2)
      .delay(fps).and().repeat(->
        @s.opacity = @s.age % 2
      , fps).then(->
        @s.opacity = 1.0
        @isDie = false
      )

    @statusTimer: fps * 5

    appendItem: (type) ->
      switch type
        when Item.type.lifeUp
          @updateHp(4)
        when Item.type.monopoly
          mpSum = @game.stage.popAllMP()
          @updateMp(mpSum)
        when Item.type.star
          @type = Item.type.star
          @typeTimer = Player.statusTimer

    isStar: ->
      @type == Item.type.star

    collision: (v) ->
      if not @isStar()
        @v.add(v.mul(6.0))
        @damage()

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

  return Player
