define ['item'], (Item) ->
  # remove global
  fps = 20
  eu = ElzupUtils
  Vector2 = tm.geom.Vector2

  getParams = eu.get_parameters()

  class Stage
    @cellSize: 8
    @widthN: 64 * 2
    @heightN: 48 * 2
    @width: Stage.widthN * Stage.cellSize
    @height: Stage.heightN * Stage.cellSize

    @widthTopN: 0
    @widthEndN: Stage.widthN - 1
    @heightTopN: 0
    @heightEndN: Stage.heightN - 1

    @type:
      flat: 0
      blocks: 1
      wall: 2
      vortex: 3
      sprite: 4

    @blockType:
      none: 0
      mp: 9
      block: 5
      wall: 6

    @initPos: [
      new Vector2(Stage.widthN / 7, Stage.heightN / 10)
      new Vector2(Stage.widthN * 6 / 7, Stage.heightN / 10)
      new Vector2(Stage.widthN / 7, Stage.heightN * 6 / 10)
      new Vector2(Stage.widthN * 6 / 7, Stage.heightN * 9 / 10)
    ]

    @widthEnds: () ->
      [Stage.widthEndN, Stage.widthTopN]

    @heightEnds: () ->
      [Stage.heightEndN, Stage.heightTopN]

    constructor: (@core) ->
      @map = new Map(Stage.cellSize, Stage.cellSize)
      @map.image = @core.assets['/images/map0.png']
      @core.rootScene.addChild(@map)
      @setupMap()
      @items = []

    setupMap: ->
      # 指定があればステージタイプを決める
      if getParams.type
        stageType = parseInt(getParams.type)
      else
        stageType = Stage.type.blocks
      if stageType in [Stage.type.flat, Stage.type.blocks]
        @baseMap = [0...Stage.heightN]
        for j in @baseMap
          @baseMap[j] = [0...Stage.widthN]
          for i in @baseMap[j]
            @baseMap[j][i] = 0
            span = 30
            col = 5
            padding = 5
            if stageType == Stage.type.blocks and
                padding < j < (Stage.heightN - padding) and
                padding < i < (Stage.widthN - padding) and
                (i + 15) % span < col and
                (j + 15) % span < col
              @baseMap[j][i] = Stage.blockType.block
            if j in Stage.heightEnds() or i in Stage.widthEnds()
              @baseMap[j][i] = Stage.blockType.wall
        @reloadMap()
      else
        if stageType == Stage.type.wall
          filename = "/data/map_wall.json"
        else if stageType == Stage.type.vortex
          filename = "/data/map_vortex.json"
        else
          filename = "/data/map_sprite.json"
        $.getJSON filename, (data) =>
          @baseMap = data
          for j in [0...Stage.heightN]
            for i in [0...Stage.widthN]
              p = @baseMap[j][i]
              if not Stage.isBlock(p) and p != Stage.blockType.none
                Stage.initPos[p - 1] = new Vector2(i, j)
          @reloadMap()
          console.log "map loaded"

    @isBlock: (type) ->
      type in Stage.wall()

    @toMpos: (spos, r = 0) ->
      [Stage.toMx(spos.x + r), Stage.toMy(spos.y + r)]

    @toMx: (sx) ->
      eu.clamp(Math.floor(sx / Stage.cellSize), Stage.widthN - 1)

    @toMy: (sy) ->
      eu.clamp(Math.floor(sy / Stage.cellSize), Stage.heightN - 1)

    @toSpos: (mx, my) ->
      new Vector2(Stage.toSx(mx), Stage.toSy(my))

    @toSx: (mx) ->
      Stage.cellSize * mx

    @toSy: (my) ->
      Stage.cellSize * my


    mapType: (spos) ->
      [mx, my] = Stage.toMpos(spos)
      @baseMap[my][mx]

    @wall: ->
      [Stage.blockType.block, Stage.blockType.wall]

    @noFill: ->
      [Stage.blockType.block, Stage.blockType.wall, Stage.blockType.mp]

    fillMp: (ox, oy, mp) ->
      k = 0
      # 中央から外側に向けて塗りつぶす
      while true
        msy = eu.clamp(oy - k, Stage.heightEndN)
        mey = eu.clamp(oy + k, Stage.heightEndN)
        msx = eu.clamp(ox - k, Stage.widthEndN)
        mex = eu.clamp(ox + k, Stage.widthEndN)
        kk = Math.pow(k, 2)
        for my in [msy..mey]
          for mx in [msx..mex]
            dx = ox - mx
            dy = oy - my
            # 円形に塗りつぶす
            if mp <= 0
              break
            type = @baseMap[my][mx] or kk < dx * dx + dy * dy
            if type in Stage.noFill()
              continue
            @baseMap[my][mx] = Stage.blockType.mp
            mp -= 1
        k += 1
        if k > Stage.heightN
          break
        if mp <= 0
          break
      @reloadMap()

    inclementItem: ->
      type = Item.getRandomType()
      [mx, my] = @getRandomEmptyMPos()
      item = new Item(mx, my, type, @core, @game, Stage.toSpos(mx, my))
      @items.push(item)
      console.log "item generated"

    getRandomEmptyMPos: ->
      i = 0
      while (true)
        i += 1
        if (i > 10000)
          console.log "safe repeat break"
          break
        [mx, my] = Stage.getRandomMPos()
        if Stage.isBlock(@baseMap[my][mx]) or @isOverlapItem(mx, my)
          continue
        return [mx, my]
      console.log "add"

    isOverlapItem: (mx, my) ->
      for key, value of @items
        if value.mx == mx and value.my == my
          return true
      return false

    @getRandomMPos: ->
      mx = eu.rand_range(Stage.widthN)
      my = eu.rand_range(Stage.heightN)
      return [mx, my]

    popAllMP: ->
      mpSum = 0
      for j in [0...Stage.heightN]
        for i in [0...Stage.widthN]
          if @baseMap[j][i] == Stage.blockType.mp
            @baseMap[j][i] = Stage.blockType.none
            mpSum += 1
      if mpSum > 0
        @reloadMap()
      return mpSum

    popSquareMP: (sPos, ePos) ->
      mpSum = 0
      [msx, msy] = Stage.toMpos(sPos)
      [mex, mey] = Stage.toMpos(ePos)
      for my in [msy..mey]
        for mx in [msx..mex]
          if @baseMap[my][mx] == Stage.blockType.mp
            @baseMap[my][mx] = Stage.blockType.none
            mpSum += 1
      if mpSum > 0
        @reloadMap()
      return mpSum

    reloadMap: ->
      @map.loadData(@baseMap)

  return Stage

