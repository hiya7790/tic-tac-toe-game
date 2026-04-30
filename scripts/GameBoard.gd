# GameBoard.gd
# Encapsulates all Tic-Tac-Toe game logic.
# UI-agnostic: knows nothing about nodes, buttons, or labels.
# Extended with clone() and empty_cells() to support the AI opponent.
#
# Public API:
#   make_move(row, col) -> bool       place a token; returns false if invalid
#   get_cell(row, col)  -> int        Player.NONE / X / O
#   clone()             -> GameBoard  deep copy for AI tree search
#   empty_cells()       -> Array      list of [row,col] pairs still available
#   reset()                           clear board for a new round
#   current_player      int           whose turn it is
#   state               int           PLAYING / WIN / DRAW
#   winning_line        Array         [[r,c],[r,c],[r,c]] when state == WIN

extends Reference
class_name GameBoard

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum Player    { NONE = 0, X = 1, O = 2 }
enum GameState { PLAYING, WIN, DRAW }

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const WIN_LINES := [
	[[0,0],[0,1],[0,2]], [[1,0],[1,1],[1,2]], [[2,0],[2,1],[2,2]],  # rows
	[[0,0],[1,0],[2,0]], [[0,1],[1,1],[2,1]], [[0,2],[1,2],[2,2]],  # cols
	[[0,0],[1,1],[2,2]], [[0,2],[1,1],[2,0]],                        # diags
]

# ---------------------------------------------------------------------------
# Public state
# ---------------------------------------------------------------------------

var current_player: int = Player.X
var state: int          = GameState.PLAYING
var winning_line: Array = []

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _cells: Array = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _init() -> void:
	reset()

func reset() -> void:
	_cells = [
		Player.NONE, Player.NONE, Player.NONE,
		Player.NONE, Player.NONE, Player.NONE,
		Player.NONE, Player.NONE, Player.NONE,
	]
	state        = GameState.PLAYING
	winning_line = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func get_cell(row: int, col: int) -> int:
	return _cells[row * 3 + col]

func make_move(row: int, col: int) -> bool:
	if state != GameState.PLAYING:
		return false
	if _cells[row * 3 + col] != Player.NONE:
		return false
	_cells[row * 3 + col] = current_player
	_evaluate()
	return true

# Returns a deep copy of this board.
# Used by AI.minimax() to explore moves without mutating the real board.
func clone() -> Reference:
	var b = get_script().new()
	b.current_player = current_player
	b.state          = state
	b.winning_line   = winning_line.duplicate()
	b._cells         = _cells.duplicate()
	return b

# Returns a list of [row, col] pairs for every empty cell.
func empty_cells() -> Array:
	var out := []
	for i in range(9):
		if _cells[i] == Player.NONE:
			out.append([i / 3, i % 3])
	return out

static func player_name(player: int) -> String:
	match player:
		Player.X: return "X"
		Player.O: return "O"
		_:        return ""

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _evaluate() -> void:
	for line in WIN_LINES:
		var a = _cells[line[0][0] * 3 + line[0][1]]
		var b = _cells[line[1][0] * 3 + line[1][1]]
		var c = _cells[line[2][0] * 3 + line[2][1]]
		if a != Player.NONE and a == b and b == c:
			state        = GameState.WIN
			winning_line = line
			return

	var has_empty := false
	for cell in _cells:
		if cell == Player.NONE:
			has_empty = true
			break

	if not has_empty:
		state = GameState.DRAW
		return

	current_player = Player.O if current_player == Player.X else Player.X
