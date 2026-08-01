extends RefCounted
class_name Constants

const CELL_SIZE := 32

const GRID_WIDTH := 40
const SURFACE_ROW := 5
const GRID_DEPTH := 90
const GRID_HEIGHT := SURFACE_ROW + GRID_DEPTH

enum Tile { EMPTY = -1, ROCK = 0, ORE = 1, CRACKED = 2, HEAT_CORE = 3, BEDROCK = 4 }
