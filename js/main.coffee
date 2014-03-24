vendors = [
  "webkit"
  "moz"
]

if not window.requestAnimationFrame
  for vendor in vendors
    window.requestAnimationFrame = window["#{vendor}RequestAnimationFrame"]
    window.cancelAnimationFrame = window["#{vendor}CancelAnimationFrame"] or window["#{vendor}CancelRequestAnimationFrame"]

unless window.requestAnimationFrame
  window.requestAnimationFrame = (callback, element) ->
    currTime = new Date().getTime()
    timeToCall = Math.max(0, 16 - (currTime - lastTime))
    id = window.setTimeout(->
      callback currTime + timeToCall
      return
    , timeToCall)
    lastTime = currTime + timeToCall
    id

unless window.cancelAnimationFrame
  window.cancelAnimationFrame = (id) ->
    clearTimeout id
    return

class LocalScoreManager
  constructor: ->
    @key = "bestScore"
    @storage = if @localStorageSupported() then window.localStorage else window.fakeStorage

  localStorageSupported: ->
    testKey = "test"
    storage = window.localStorage
    try
      storage.setItem testKey, "1"
      storage.removeItem testKey
    catch error
      return no
    yes

  get: ->
    @storage.getItem(@key) or 0

  set: (score) ->
    @storage.setItem @key, score
    return

window.fakeStorage =
  _data: {}
  setItem: (id, val) ->
    return_data[id] = String(val)
  getItem: (id) ->
    (if @_data.hasOwnProperty(id) then @_data[id] else `undefined`)
  removeItem: (id) ->
    delete @_data[id]
  clear: ->
    return_data = {}

class KeyboardInputManager
  constructor : ->
    @events = {}
    @listen()

  On: (event, callback) ->
    @events[event] ?= []
    @events[event].push callback
    return

  emit: (event, data) ->
    callbacks = @events[event]
    if callbacks
      callbacks.forEach (callback) ->
        callback data
        return
    return

  listen: ->
    self = @
    moveMap =
      81: 2 # Q
      67: 3 # C
      69: 4 # E
      90: 5 # Z
    horizontalMap =
      37: 0 # Left
      39: 1 # Right
      72: 0 # vim
      76: 1
      65: 0 # A
      68: 1 # D
    verticalMap =
      38: 2 # Up
      40: 5 # Down
      75: 2 # vim keybindings
      74: 5
      87: 2 # W
      83: 5 # S
    holdingKeys = {}
    document.addEventListener "keydown", (event) ->
      modifiers = event.altKey or event.ctrlKey or event.metaKey or event.shiftKey
      mapped = verticalMap[event.which] or horizontalMap[event.which]
      unless modifiers
        if mapped isnt undefined
          holdingKeys[event.which] = yes
          event.preventDefault()
        self.restart.bind(self) event if event.which is 32
      return
    document.addEventListener "keyup", (event) ->
      detectDirection = (key1, key2) ->
        mapped1 = verticalMap[key1] or horizontalMap[key1]
        mapped2 = verticalMap[key2] or horizontalMap[key2]
        mapped1 = mapped2 + mapped1 - (mapped2 = mapped1) if mapped1 > mapped2
        switch mapped2
          when 2
            mapped1 * 2 + mapped2
          when 5
            mapped2 - mapped1 * 2
      modifiers = event.altKey or event.ctrlKey or event.metaKey or event.shiftKey
      mapped = moveMap[event.which]
      unless modifiers
        holdingKeys[event.which] = no if holdingKeys[event.which]
        if mapped isnt undefined
          event.preventDefault()
          self.emit "move", mapped
        else
          i = j = 0
          for t of holdingKeys
            if holdingKeys[t]
              i++
              key = t
            j++
          if i is 0
            self.emit "move", horizontalMap[event.which] if j is 1 and horizontalMap[event.which] isnt undefined
            delete holdingKeys[t] for t of holdingKeys if j > 0
          else if i is 1 and ((verticalMap[key] isnt undefined and horizontalMap[event.which] isnt undefined) or (horizontalMap[key] isnt undefined and verticalMap[event.which] isnt undefined))
            direction = detectDirection key, event.which
            event.preventDefault()
            self.emit "move", direction
      return
    retry = document.querySelector ".retry-button"
    retry.addEventListener "click", @restart.bind @
    retry.addEventListener "touchend", @restart.bind @
    keepPlaying = document.querySelector ".keep-playing-button"
    keepPlaying.addEventListener "click", @keepPlaying.bind @
    keepPlaying.addEventListener "touchend", @keepPlaying.bind @
    # Listen to swipe events
    touchStartClientX =  touchStartClientY = 0
    gameContainer = document.getElementsByClassName("game-container")[0]
    gameContainer.addEventListener "touchstart", (event) ->
      return if event.touches.length > 1
      touchStartClientX = event.touches[0].clientX
      touchStartClientY = event.touches[0].clientY
      event.preventDefault()
      return
    gameContainer.addEventListener "touchmove", (event) ->
      event.preventDefault()
      return
    gameContainer.addEventListener "touchend", (event) ->
      return if event.touches.length > 0
      dx = event.changedTouches[0].clientX - touchStartClientX
      absDx = Math.abs dx
      dy = event.changedTouches[0].clientY - touchStartClientY
      absDy = Math.abs dy
      tan = dy / dx
      angle = Math.atan(dy / dx) / Math.PI * 180
      delta = 20
      switch yes
        when angle < 0 + delta and angle > 0 - delta
          direction = if dx > 0 then 1 else 0
        when angle < 60 + delta and angle > 60 - delta
          direction = if dx > 0 then 3 else 2
        when angle < -60 + delta and angle > -60 - delta
          direction = if dx > 0 then 4 else 5
      self.emit "move", direction if direction isnt undefined
      return
    return

  restart: (event) ->
    event.preventDefault()
    @emit "restart"
    return

  keepPlaying: (event) ->
    event.preventDefault()
    @emit "keepPlaying"
    return

class Grid
  constructor: (size) ->
    @size = size
    @cells = []
    @cellCount = []
    @build()

  # Build a grid of the specified size
  build: ->
    for x in [0...@size]
      row = @cells[x] = []
      y = @size
      row.push null while y--
    return

  _count: (value, amount) ->
    index = Math.floor Math.log(value) / Math.log(2)
    @cellCount.push 0 while @cellCount.length <= index
    @cellCount[index] += amount
    return

  # Find the first available random position
  randomAvailableCell: ->
    cells = @availableCells()
    cells[Math.floor Math.random() * cells.length] if cells.length

  availableCells: ->
    cells = []
    self = @
    @eachCell (x, y, tile) ->
      if not tile and self.withinBounds(
        x: x
        y: y
      )
        cells.push
          x: x
          y: y
      return
    cells

  # Call callback for every cell
  eachCell: (callback) ->
    callback x, y, @cells[x][y] for y in [0...@size] for x in [0...@size]
    return

  # Check if there are any cells available
  cellsAvailable: ->
    !!@availableCells().length

  # Check if the specified cell is taken
  cellAvailable: (cell) ->
    not @cellOccupied(cell)

  cellOccupied: (cell) ->
    !!@cellContent(cell)

  cellContent: (cell) ->
    if @withinBounds(cell) then @cells[cell.x][cell.y] else null

  # Inserts a tile at its position
  insertTile: (tile) ->
    @_count @cells[tile.x][tile.y].value, -1 if @cells[tile.x][tile.y]
    @cells[tile.x][tile.y] = tile
    @_count tile.value, 1
    return

  removeTile: (tile) ->
    @cells[tile.x][tile.y] = null
    @_count tile.value, -1
    return

  withinBounds: (position) ->
    position.x >= 0 and position.x < @size - Math.abs(position.y - 2) and position.y >= 0 and position.y < @size and (position.x isnt 2 or position.y isnt 2)

class Tile
  constructor: (position, value) ->
    @x = position.x
    @y = position.y
    @value = value or 2
    @previousPosition = null
    @mergedFrom = null # Tracks tiles that merged together

  savePosition: ->
    @previousPosition =
      x: @x
      y: @y
    return

  updatePosition: (position) ->
    @x = position.x
    @y = position.y
    return

class HTMLActuator
  constructor: ->
    @tileContainer = document.querySelector(".tile-container")
    @scoreContainer = document.querySelector(".score-container")
    @bestContainer = document.querySelector(".best-container")
    @messageContainer = document.querySelector(".game-message")
    @score = 0

  actuate: (grid, metadata) ->
    self = @
    window.requestAnimationFrame ->
      self.clearContainer self.tileContainer
      grid.cells.forEach (column) ->
        column.forEach (cell) ->
          self.addTile cell if cell
          return
        return
      self.updateScore metadata.score
      self.updateBestScore metadata.bestScore
      if metadata.terminated
        if metadata.over then self.message no # You lose
        else self.message yes if metadata.won # You win!
      return
    return

  # Continues the game (both restart and keep playing)
  continue_: ->
    @clearMessage()

  clearContainer: (container) ->
    container.removeChild container.firstChild while container.firstChild

  addTile: (tile) ->
    self = @
    wrapper = document.createElement("div")
    inner = document.createElement("div")
    position = tile.previousPosition or
      x: tile.x
      y: tile.y
    positionClass = @positionClass position
    # We can't use classlist because it somehow glitches when replacing classes
    classes = [
      "tile"
      "tile-" + tile.value
      positionClass
    ]
    classes.push "tile-super" if tile.value > 2048
    @applyClasses wrapper, classes
    inner.classList.add "tile-inner"
    inner.textContent = tile.value
    if tile.previousPosition
      # Make sure that the tile gets rendered in the previous position first
      window.requestAnimationFrame ->
        classes[2] = self.positionClass(
          x: tile.x
          y: tile.y
        )
        self.applyClasses wrapper, classes # Update the position
        return
    else if tile.mergedFrom
      classes.push "tile-merged"
      @applyClasses wrapper, classes
      # Render the tiles that merged
      tile.mergedFrom.forEach (merged) ->
        self.addTile merged
        return
    else
      classes.push "tile-new"
      @applyClasses wrapper, classes
    # Add the inner part of the tile to the wrapper
    wrapper.appendChild inner
    # Put the tile on the board
    @tileContainer.appendChild wrapper
    return

  applyClasses: (element, classes) ->
    element.setAttribute "class", classes.join " "
    return

  normalizePosition: (position) ->
    map = [
      [{r: 2, theta: 120}, {r: 2, theta: 90}, {r: 2, theta: 60}],
      [{r: 2, theta: 150}, {r: 1, theta: 120}, {r: 1, theta: 60}, {r: 2, theta: 30}],
      [{r: 2, theta: 180}, {r: 1, theta: 180}, {r: 0, theta: 0}, {r: 1, theta: 0}, {r: 2, theta: 0}],
      [{r: 2, theta: 210}, {r: 1, theta: 240}, {r: 1, theta: 300}, {r: 2, theta: 330}],
      [{r: 2, theta: 240}, {r: 2, theta: 270}, {r: 2, theta: 300}],
    ]
    map[position.y][position.x]

  positionClass: (position) ->
    position = @normalizePosition position
    "tile-position-#{position.r}-#{position.theta}"

  updateScore: (score) ->
    @clearContainer @scoreContainer
    difference = score - @score
    @score = score
    @scoreContainer.textContent = @score
    if difference > 0
      addition = document.createElement "div"
      addition.classList.add "score-addition"
      addition.textContent = "+#{difference}"
      @scoreContainer.appendChild addition
    return

  updateBestScore: (bestScore) ->
    @bestContainer.textContent = bestScore
    return

  message: (won) ->
    type = if won then "game-won" else "game-over"
    message = if won then "You win!" else "Game over!"
    @messageContainer.classList.add type
    @messageContainer.getElementsByTagName("p")[0].textContent = message
    return

  clearMessage: ->
    # IE only takes one value to remove at a time.
    @messageContainer.classList.remove "game-won"
    @messageContainer.classList.remove "game-over"
    return

class GameManager
  constructor: (size, InputManager, Actuator, ScoreManager) ->
    @size = size
    @inputManager = new InputManager()
    @scoreManager = new ScoreManager()
    @actuator = new Actuator()
    @startTiles = 2
    @maxNum = 0
    @inputManager.On "move", @move.bind @
    @inputManager.On "restart", @restart.bind @
    @inputManager.On "keepPlaying", @keepPlaying.bind @
    @setup()

  # Restart the game
  restart: ->
    @actuator.continue_()
    @setup()
    return

  # Keep playing after winning
  keepPlaying: ->
    @keepPlaying = yes
    @actuator.continue_()

  isGameTerminated: ->
    @over or (@won and not @keepPlaying)

  setup: ->
    @grid = new Grid @size
    @score = 0
    @over = no
    @won = no
    @keepPlaying = no
    @maxNum = 0
    # Add the initial tiles
    @addStartTiles()
    # Update the actuator
    @actuate()
    return

  # Set up the initial tiles to start the game with
  addStartTiles: ->
    @addRandomTile() for i in [0...@startTiles]
    return

  # Adds a tile in a random position
  addRandomTile: ->
    if @grid.cellsAvailable()
      rand = Math.random()
      n = 0
      pvalues = Math.pow 2, i if cell % 2 isnt 0 or Math.pow(2, i) >= @maxNum / Math.pow(@maxNum, 0.7) / 2 for cell, i in @grid.cellCount
      value = pvalues[0]
      for pvalue, i in pvalues
        n += 0.9 * Math.pow 10, i + 1
        value = pvalue if rand > n
      @grid.insertTile new Tile @grid.randomAvailableCell(), value
    return

  # Sends the updated grid to the actuator
  actuate: ->
    @scoreManager.set @score if @scoreManager.get() < @score
    @actuator.actuate @grid,
      score: @score
      over: @over
      won: @won
      bestScore: @scoreManager.get()
      terminated: @isGameTerminated()
    return

  # Save all tile positions and remove merger info
  prepareTiles: ->
    @grid.eachCell (x, y, tile) ->
      if tile
        tile.mergedFrom = null
        tile.savePosition()
      return
    return

  # Move a tile and its representation
  moveTile: (tile, cell) ->
    @grid.cells[tile.x][tile.y] = null
    @grid.cells[cell.x][cell.y] = tile
    tile.updatePosition cell
    return

  # Move tiles on the grid in the specified direction
  move: (direction) ->
    # 0: up, 1: right, 2:down, 3: left
    self = @
    return if @isGameTerminated() # Don't do anything if the game's over
    traversals = @buildTraversals direction
    moved = no
    # Save the current tile positions and remove merger information
    @prepareTiles()
    # Traverse the grid in the right direction and move tiles
    traversals.forEach (cells) ->
      cells.forEach (cell) ->
        tile = self.grid.cellContent cell
        if tile
          positions = self.findFarthestPosition cell, direction
          next = self.grid.cellContent positions.next
          # Only one merger per row traversal?
          if next and next.value is tile.value and not next.mergedFrom
            merged = new Tile positions.next, tile.value * 2
            merged.mergedFrom = [tile, next]
            self.grid.insertTile merged
            self.grid.removeTile tile
            # Converge the two tiles' positions
            tile.updatePosition positions.next
            # Update the score
            self.score += merged.value
            self.maxNum = Math.max self.maxNum, merged.value
            # The mighty 2048 tile
            self.won = yes if merged.value is 2048
          else self.moveTile tile, positions.farthest
          moved = yes unless self.positionsEqual cell, tile # The tile moved from its original cell!
        return
      return
    if moved
      @addRandomTile()
      @addRandomTile() if Math.random() > 0.25
      @over = yes unless @movesAvailable() # Game over!
      @actuate()
    return

  # Get the vector representing the chosen direction
  getVector: (direction, cell) ->
    # Vectors representing tile movement
    map =
      0: # left
        x: -1
        y: 0
      1: # right
        x: 1
        y: 0
    return map[direction] if map[direction]
    vector =
      x: 0
      y: 0
    switch direction
      when 2
        vector.x = -1 if cell.y < 3
        vector.y = -1
      when 3
        vector.x = 1 if cell.y < 2
        vector.y = 1
      when 4
        vector.x = 1 if cell.y > 2
        vector.y = -1
      when 5
        vector.x = -1 if cell.y > 1
        vector.y = 1
    vector

  # Build a list of positions to traverse in the right order
  buildTraversals: (direction) ->
    _map =
      0: [
        [{ x: 0,  y: 0 }, { x: 1,  y: 0 }, { x: 2,  y: 0 }],
        [{ x: 0,  y: 1 }, { x: 1,  y: 1 }, { x: 2,  y: 1 }, { x: 3,  y: 1 }],
        [{ x: 0,  y: 2 }, { x: 1,  y: 2 }, { x: 2,  y: 2 }, { x: 3,  y: 2 }, { x: 4,  y: 2 }],
        [{ x: 0,  y: 3 }, { x: 1,  y: 3 }, { x: 2,  y: 3 }, { x: 3,  y: 3 }],
        [{ x: 0,  y: 4 }, { x: 1,  y: 4 }, { x: 2,  y: 4 }],
      ],
      2: [
        [{ x: 2,  y: 0 }, { x: 3,  y: 1 }, { x: 4,  y: 2 }],
        [{ x: 1,  y: 0 }, { x: 2,  y: 1 }, { x: 3,  y: 2 }, { x: 3,  y: 3 }],
        [{ x: 0,  y: 0 }, { x: 1,  y: 1 }, { x: 2,  y: 2 }, { x: 2,  y: 3 }, { x: 2,  y: 4 }],
        [{ x: 0,  y: 1 }, { x: 1,  y: 2 }, { x: 1,  y: 3 }, { x: 1,  y: 4 }],
        [{ x: 0,  y: 2 }, { x: 0,  y: 3 }, { x: 0,  y: 4 }],
      ],
      4: [
        [{ x: 0,  y: 0 }, { x: 0,  y: 1 }, { x: 0,  y: 2 }],
        [{ x: 1,  y: 0 }, { x: 1,  y: 1 }, { x: 1,  y: 2 }, { x: 0,  y: 3 }],
        [{ x: 2,  y: 0 }, { x: 2,  y: 1 }, { x: 2,  y: 2 }, { x: 1,  y: 3 }, { x: 0,  y: 4 }],
        [{ x: 3,  y: 1 }, { x: 3,  y: 2 }, { x: 2,  y: 3 }, { x: 1,  y: 4 }],
        [{ x: 4,  y: 2 }, { x: 3,  y: 3 }, { x: 2,  y: 4 }],
      ],
    for i in [0...6] by 2
      _map[i + 1] = []
      _map[i + 1].push mapi.slice().reverse() for mapi in _map[i]
    _map[direction]

  findFarthestPosition: (cell, direction) ->
    # Progress towards the vector direction until an obstacle is found
    loop
      vector = @getVector(direction, cell)
      previous = cell
      cell =
        x: previous.x + vector.x
        y: previous.y + vector.y
      break unless @grid.withinBounds(cell) and @grid.cellAvailable(cell)
    farthest: previous
    next: cell # Used to check if a merge is required

  movesAvailable: ->
    @grid.cellsAvailable() or @tileMatchesAvailable()

  # Check for available matches between tiles (more expensive check)
  tileMatchesAvailable: ->
    self = @
    tile = null
    for x in [0...@size]
      for y in [0...@size]
        tile = @grid.cellContent(
          x: x
          y: y
        )
      if tile
        direction = 0
        while direction < 6
          vector = self.getVector(direction,
            x: x
            y: y
          )
          cell =
            x: x + vector.x
            y: y + vector.y
          other = self.grid.cellContent(cell)
          return yes if other and other.value is tile.value # These two tiles can be merged
          direction++
    no

  positionsEqual: (first, second) ->
    first.x is second.x and first.y is second.y

window.requestAnimationFrame ->
  new GameManager 5, KeyboardInputManager, HTMLActuator, LocalScoreManager
  return