# Main.gd
# UI controller for the Tic-Tac-Toe game.
#
# Responsibilities:
#   • Own a GameBoard instance and call its API on every player action.
#   • When in AI mode, schedule an AI move after each human move.
#   • Keep all visual state (cell buttons, labels, score, win highlight)
#     in sync with the logical state after each move.
#   • Track cross-round scores and game mode / difficulty settings.
#
# Node layout expected in Main.tscn:
#   Main (Node2D)
#   └── UI (Control)
#       ├── Title (Label)
#       ├── ModeBar (HBoxContainer)
#       │   ├── Btn2P (Button)
#       │   └── BtnAI (Button)
#       ├── DiffBar (HBoxContainer)          ← visible only in AI mode
#       │   ├── LabelDiff (Label)
#       │   ├── BtnEasy (Button)
#       │   ├── BtnMedium (Button)
#       │   └── BtnHard (Button)
#       ├── ScoreBar (HBoxContainer)
#       │   ├── ScoreX (Label)
#       │   ├── ScoreSep (Label)
#       │   └── ScoreO (Label)
#       ├── StatusLabel (Label)
#       ├── Grid (GridContainer)             ← 9 Button children (Cell00…Cell22)
#       └── RestartButton (Button)

extends Node2D

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const COLOR_DEFAULT := Color(0.11, 0.11, 0.16)   # idle cell
const COLOR_X       := Color(0.10, 0.23, 0.43)   # X cell background (blue)
const COLOR_O       := Color(0.35, 0.10, 0.10)   # O cell background (red)
const COLOR_WIN     := Color(0.05, 0.20, 0.13)   # winning-line highlight (green)
const COLOR_BORDER_DEFAULT := Color(0.16, 0.16, 0.22)
const COLOR_BORDER_X       := Color(0.29, 0.56, 0.91)
const COLOR_BORDER_O       := Color(0.88, 0.33, 0.33)
const COLOR_BORDER_WIN     := Color(0.18, 0.83, 0.46)

# Delay (ms) before the AI plays its move — gives visual feedback
const AI_DELAY_EASY   := 380
const AI_DELAY_MEDIUM := 560
const AI_DELAY_HARD   := 750

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------

onready var _status_label  : Label         = $UI/StatusLabel
onready var _score_x_label : Label         = $UI/ScoreBar/ScoreX
onready var _score_o_label : Label         = $UI/ScoreBar/ScoreO
onready var _grid          : GridContainer = $UI/Grid
onready var _restart_btn   : Button        = $UI/RestartButton
onready var _diff_bar      : HBoxContainer = $UI/DiffBar
onready var _btn_2p        : Button        = $UI/ModeBar/Btn2P
onready var _btn_ai        : Button        = $UI/Center/ModeBar/BtnAI
onready var _btn_online    : Button        = $UI/Center/ModeBar/BtnOnline
onready var _btn_easy      : Button        = $UI/Center/DiffBar/BtnEasy
onready var _btn_medium    : Button        = $UI/Center/DiffBar/BtnMedium
onready var _btn_hard      : Button        = $UI/Center/DiffBar/BtnHard
onready var _online_bar    : HBoxContainer = $UI/Center/OnlineBar
onready var _room_input    : LineEdit      = $UI/Center/OnlineBar/RoomInput
onready var _btn_create    : Button        = $UI/Center/OnlineBar/BtnCreate
onready var _btn_join      : Button        = $UI/Center/OnlineBar/BtnJoin

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _board       : GameBoard
var _score_x     : int = 0
var _score_o     : int = 0
var _mode        : String = "2p"      # "2p" | "ai"
var _difficulty  : int = AI.Difficulty.MEDIUM
var _ai_player   : int = GameBoard.Player.O  # AI always plays O
var _ai_thinking : bool = false

var _network     : Node
var _online_side : int = GameBoard.Player.NONE
var _online_active: bool = false

var _cell_buttons : Array = []  # [Button × 9], row-major

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_network = preload("res://scripts/Network.gd").new()
	add_child(_network)
	_network.connect("connected", self, "_on_net_connected")
	_network.connect("room_created", self, "_on_room_created")
	_network.connect("room_joined", self, "_on_room_joined")
	_network.connect("game_start", self, "_on_game_start")
	_network.connect("state_update", self, "_on_state_update")
	_network.connect("game_restart", self, "_on_game_start")
	_network.connect("player_disconnected", self, "_on_player_disconnected")

	_build_cell_index()
	_connect_signals()
	_start_new_round()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _build_cell_index() -> void:
	_cell_buttons.clear()
	for child in _grid.get_children():
		if child is Button:
			_cell_buttons.append(child)

func _connect_signals() -> void:
	for i in range(_cell_buttons.size()):
		_cell_buttons[i].connect("pressed", self, "_on_cell_pressed", [i])

	_restart_btn.connect("pressed", self, "_on_restart_pressed")
	_btn_2p.connect("pressed",      self, "_on_mode_pressed",  ["2p"])
	_btn_ai.connect("pressed",      self, "_on_mode_pressed",  ["ai"])
	_btn_online.connect("pressed",  self, "_on_mode_pressed",  ["online"])
	_btn_create.connect("pressed",  self, "_on_create_pressed")
	_btn_join.connect("pressed",    self, "_on_join_pressed")
	_btn_easy.connect("pressed",    self, "_on_diff_pressed",  [AI.Difficulty.EASY])
	_btn_medium.connect("pressed",  self, "_on_diff_pressed",  [AI.Difficulty.MEDIUM])
	_btn_hard.connect("pressed",    self, "_on_diff_pressed",  [AI.Difficulty.HARD])

# ---------------------------------------------------------------------------
# Round management
# ---------------------------------------------------------------------------

func _start_new_round() -> void:
	_board = GameBoard.new()
	_board.current_player = GameBoard.Player.X
	_ai_thinking = false

	_refresh_all_cells()
	_refresh_status()
	_refresh_scores()
	_refresh_mode_buttons()
	_restart_btn.visible = false

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_cell_pressed(index: int) -> void:
	if _mode == "online":
		if _online_active and _board.current_player == _online_side:
			_network.make_move(index / 3, index % 3)
		return

	if _ai_thinking:
		return
	# Ignore clicks when it is the AI's turn
	if _mode == "ai" and _board.current_player == _ai_player:
		return

	if not _board.make_move(index / 3, index % 3):
		return

	_refresh_all_cells()
	_refresh_status()

	if _board.state != GameBoard.GameState.PLAYING:
		_on_round_ended()
		return

	# Schedule AI move if it's now the AI's turn
	if _mode == "ai" and _board.current_player == _ai_player:
		_schedule_ai_move()

func _on_restart_pressed() -> void:
	if _mode == "online":
		_network.restart_game()
	else:
		_start_new_round()

func _on_mode_pressed(mode: String) -> void:
	_mode    = mode
	_score_x = 0
	_score_o = 0
	_diff_bar.visible = (mode == "ai")
	_online_bar.visible = (mode == "online")
	if mode == "online":
		_network.connect_to_server("ws://localhost:18563/ws")
		_online_active = false
		_disable_all_cells()
		_status_label.text = "Connecting..."
	else:
		_start_new_round()

func _on_diff_pressed(difficulty: int) -> void:
	_difficulty = difficulty
	_score_x    = 0
	_score_o    = 0
	_start_new_round()

func _on_round_ended() -> void:
	if _board.state == GameBoard.GameState.WIN:
		_highlight_winning_line()
		if _board.current_player == GameBoard.Player.X:
			_score_x += 1
		else:
			_score_o += 1
		_refresh_scores()
	_restart_btn.visible = true

# ---------------------------------------------------------------------------
# AI scheduling
# ---------------------------------------------------------------------------

func _schedule_ai_move() -> void:
	_ai_thinking = true
	_disable_all_cells()

	var delay := AI_DELAY_MEDIUM
	match _difficulty:
		AI.Difficulty.EASY:   delay = AI_DELAY_EASY
		AI.Difficulty.HARD:   delay = AI_DELAY_HARD

	yield(get_tree().create_timer(delay / 1000.0), "timeout")

	var move = AI.pick_move(_board, _difficulty, _ai_player)
	if move.empty():
		_ai_thinking = false
		return

	_board.make_move(move[0], move[1])
	_ai_thinking = false

	_refresh_all_cells()
	_refresh_status()

	if _board.state != GameBoard.GameState.PLAYING:
		_on_round_ended()

# ---------------------------------------------------------------------------
# Visual refresh
# ---------------------------------------------------------------------------

func _refresh_all_cells() -> void:
	for i in range(_cell_buttons.size()):
		var btn   : Button = _cell_buttons[i]
		var owner := _board.get_cell(i / 3, i % 3)
		var playing := _board.state == GameBoard.GameState.PLAYING

		match owner:
			GameBoard.Player.X:
				btn.text = "X"
				_set_button_color(btn, COLOR_X, COLOR_BORDER_X)
				btn.disabled = true
			GameBoard.Player.O:
				btn.text = "O"
				_set_button_color(btn, COLOR_O, COLOR_BORDER_O)
				btn.disabled = true
			_:
				btn.text     = ""
				btn.disabled = not playing
				_set_button_color(btn, COLOR_DEFAULT, COLOR_BORDER_DEFAULT)

func _refresh_status() -> void:
	match _board.state:
		GameBoard.GameState.PLAYING:
			if _mode == "online":
				_status_label.text = "Your turn!" if _board.current_player == _online_side else "Waiting for opponent..."
			elif _mode == "ai" and _board.current_player == _ai_player:
				_status_label.text = "Computer is thinking…"
			else:
				_status_label.text = "Player %s's turn" % GameBoard.player_name(_board.current_player)
		GameBoard.GameState.WIN:
			if _mode == "online":
				_status_label.text = "You win! 🎉" if _board.current_player == _online_side else "Opponent wins!"
			elif _mode == "ai":
				_status_label.text = "Computer wins!" if _board.current_player == _ai_player else "You win! 🎉"
			else:
				_status_label.text = "Player %s wins! 🎉" % GameBoard.player_name(_board.current_player)
		GameBoard.GameState.DRAW:
			_status_label.text = "It's a draw!"

func _refresh_scores() -> void:
	var x_label := "You" if _mode == "ai" else "X"
	var o_label := "CPU" if _mode == "ai" else "O"
	_score_x_label.text = "%s  %d" % [x_label, _score_x]
	_score_o_label.text = "%d  %s" % [_score_o, o_label]

func _refresh_mode_buttons() -> void:
	_diff_bar.visible = (_mode == "ai")
	_online_bar.visible = (_mode == "online")

func _highlight_winning_line() -> void:
	for cell_pos in _board.winning_line:
		var idx := cell_pos[0] * 3 + cell_pos[1]
		_set_button_color(_cell_buttons[idx], COLOR_WIN, COLOR_BORDER_WIN)

func _disable_all_cells() -> void:
	for btn in _cell_buttons:
		btn.disabled = true

# Applies a flat StyleBoxFlat background to a button (all four interaction states).
func _set_button_color(btn: Button, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = bg
	style.border_color               = border
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	btn.add_stylebox_override("normal",   style)
	btn.add_stylebox_override("hover",    style)
	btn.add_stylebox_override("pressed",  style)
	btn.add_stylebox_override("disabled", style)

# ---------------------------------------------------------------------------
# Network handlers
# ---------------------------------------------------------------------------

func _on_net_connected() -> void:
	if _mode == "online":
		_status_label.text = "Connected. Create or Join a Room."

func _on_create_pressed() -> void:
	if _mode == "online":
		_network.create_room()

func _on_join_pressed() -> void:
	if _mode == "online" and _room_input.text != "":
		_network.join_room(_room_input.text.strip_edges())

func _on_room_created(room_id: String, player: String) -> void:
	_online_side = GameBoard.Player.X if player == "X" else GameBoard.Player.O
	_status_label.text = "Room %s Created. Waiting for opponent..." % room_id

func _on_room_joined(room_id: String, player: String) -> void:
	_online_side = GameBoard.Player.X if player == "X" else GameBoard.Player.O
	_status_label.text = "Joined %s. Waiting for opponent..." % room_id

func _on_game_start(starting_player: String, board_data: Dictionary) -> void:
	_online_active = true
	_apply_server_board(board_data)
	_restart_btn.visible = false

func _on_state_update(board_data: Dictionary, _last_move: Dictionary) -> void:
	_apply_server_board(board_data)
	if _board.state != GameBoard.GameState.PLAYING:
		_online_active = false
		if _board.state == GameBoard.GameState.WIN:
			_highlight_winning_line()
			if _board.current_player == GameBoard.Player.X:
				_score_x += 1
			else:
				_score_o += 1
			_refresh_scores()
		_restart_btn.visible = true

func _on_player_disconnected() -> void:
	_online_active = false
	_status_label.text = "Opponent disconnected."

func _apply_server_board(board_data: Dictionary) -> void:
	if not _board:
		_board = GameBoard.new()
	
	_board.current_player = GameBoard.Player.X if board_data["current_player"] == "X" else GameBoard.Player.O
	
	var state_str = board_data["state"]
	if state_str == "WIN": _board.state = GameBoard.GameState.WIN
	elif state_str == "DRAW": _board.state = GameBoard.GameState.DRAW
	else: _board.state = GameBoard.GameState.PLAYING
	
	_board.winning_line = board_data.get("winning_line", [])
	
	var cells = board_data["cells"]
	for i in range(9):
		var val = cells[i]
		if val == "X": _board._cells[i] = GameBoard.Player.X
		elif val == "O": _board._cells[i] = GameBoard.Player.O
		else: _board._cells[i] = GameBoard.Player.NONE
		
	_refresh_all_cells()
	_refresh_status()
