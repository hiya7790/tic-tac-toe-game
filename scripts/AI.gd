# AI.gd
# Stateless AI opponent for Tic-Tac-Toe.
#
# Three difficulty levels:
#   EASY   — picks a random empty cell every time.
#   MEDIUM — uses full minimax 60% of the time, random 40% (beatable).
#   HARD   — alpha-beta minimax, optimal and unbeatable.
#
# Usage:
#   var move = AI.pick_move(board, AI.Difficulty.HARD, GameBoard.Player.O)
#   # move is [row, col], or [] if the board is full.

extends Reference
class_name AI

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

enum Difficulty { EASY, MEDIUM, HARD }

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# Returns [row, col] for the AI's chosen move, or [] if no moves remain.
# board      — a GameBoard instance (will be cloned internally; never mutated)
# difficulty — AI.Difficulty constant
# ai_player  — which Player enum value the AI controls
static func pick_move(board, difficulty: int, ai_player: int) -> Array:
	var empty = board.empty_cells()
	if empty.empty():
		return []

	if difficulty == Difficulty.EASY:
		return empty[randi() % empty.size()]

	# MEDIUM: play randomly 40% of the time to be imperfect
	if difficulty == Difficulty.MEDIUM and randf() < 0.40:
		return empty[randi() % empty.size()]

	# HARD (and MEDIUM's optimal 60%): full alpha-beta minimax
	return _minimax(board, ai_player, true, -INF, INF).move

# ---------------------------------------------------------------------------
# Private: alpha-beta minimax
# ---------------------------------------------------------------------------

# Returns a Dictionary { score: float, move: Array([row,col] or []) }.
# maximising == true  → AI's turn (tries to maximise score)
# maximising == false → human's turn (tries to minimise score)
static func _minimax(board, ai_player: int, maximising: bool, alpha: float, beta: float) -> Dictionary:
	# Terminal states
	if board.state == GameBoard.GameState.WIN:
		# current_player is the winner (evaluation happens before the turn flip)
		var score = 10.0 if board.current_player == ai_player else -10.0
		return { "score": score, "move": [] }
	if board.state == GameBoard.GameState.DRAW:
		return { "score": 0.0, "move": [] }

	var best_score := -INF if maximising else INF
	var best_move  := []

	for cell in board.empty_cells():
		var child = board.clone()
		child.make_move(cell[0], cell[1])

		var result = _minimax(child, ai_player, not maximising, alpha, beta)

		if maximising:
			if result.score > best_score:
				best_score = result.score
				best_move  = cell
			alpha = max(alpha, best_score)
		else:
			if result.score < best_score:
				best_score = result.score
				best_move  = cell
			beta = min(beta, best_score)

		if beta <= alpha:
			break  # prune remaining branches

	return { "score": best_score, "move": best_move }
