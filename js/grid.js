function Grid(size) {
  this.size = size;

  this.cells = [];
	this.cellCount = [];

  this.build();
}

// Build a grid of the specified size
Grid.prototype.build = function () {
  for (var x = 0; x < this.size; x++) {
    var row = this.cells[x] = [];

    for (var y = 0; y < this.size; y++) {
      row.push(null);
    }
  }
};

// Find the first available random position
Grid.prototype.randomAvailableCell = function () {
  var cells = this.availableCells();

  if (cells.length) {
    return cells[Math.floor(Math.random() * cells.length)];
  }
};

Grid.prototype.availableCells = function () {
  var cells = [];
  var self = this;
  this.eachCell(function (x, y, tile) {
    if (!tile && self.withinBounds({ x: x, y: y })) {
      cells.push({ x: x, y: y });
    }
  });

  return cells;
};

// Call callback for every cell
Grid.prototype.eachCell = function (callback) {
  for (var x = 0; x < this.size; x++) {
    for (var y = 0; y < this.size; y++) {
      callback(x, y, this.cells[x][y]);
    }
  }
};

// Check if there are any cells available
Grid.prototype.cellsAvailable = function () {
  return !!this.availableCells().length;
};

// Check if the specified cell is taken
Grid.prototype.cellAvailable = function (cell) {
  return !this.cellOccupied(cell);
};

Grid.prototype.cellOccupied = function (cell) {
  return !!this.cellContent(cell);
};

Grid.prototype.cellContent = function (cell) {
  if (this.withinBounds(cell)) {
    return this.cells[cell.x][cell.y];
  } else {
    return null;
  }
};

// Inserts a tile at its position
Grid.prototype.insertTile = function (tile) {
	if(this.cells[tile.x][tile.y])
		this.count(this.cells[tile.x][tile.y].value, -1);
  this.cells[tile.x][tile.y] = tile;
	this.count(tile.value, 1);
};

Grid.prototype.removeTile = function (tile) {
  this.cells[tile.x][tile.y] = null;
	this.count(tile.value, -1);
};

Grid.prototype.count = function(value, amount) {
	var index = Math.floor(Math.log(value) / Math.log(2));
	while(this.cellCount.length <= index)
		this.cellCount.push(0);
	this.cellCount[index] += amount;
};


Grid.prototype.withinBounds = function (position) {
  return position.x >= 0 && position.x < this.size - Math.abs(position.y - 2) &&
         position.y >= 0 && position.y < this.size && (position.x != 2 || position.y != 2);
};