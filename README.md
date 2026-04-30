# Tic-Tac-Toe — Godot 3 Project

A two-player and single-player Tic-Tac-Toe game built in Godot 3.5.  
Design priorities: **working game → clean code → good UI**.

---

## Project layout

```
tictactoe/
├── project.godot          # Godot project configuration
├── default_env.tres       # required environment resource
├── icon.png               # window / app icon
│
├── scripts/
│   ├── GameBoard.gd       # ★ pure game logic — no UI, no nodes
│   ├── AI.gd              # ★ stateless AI opponent (minimax)
│   └── Main.gd            # UI controller — wires logic to the scene tree
│
├── scenes/
│   └── Main.tscn          # full scene tree with mode/difficulty UI
│
└── export/
    └── index.html         # standalone HTML5 deployment (see below)
```

---

## Architecture

Strict **logic / presentation split** across three layers:

### `GameBoard.gd` — game rules
A `Reference`-based class with no Node or scene dependencies.

| Member | Type | Description |
|--------|------|-------------|
| `current_player` | `Player` enum | Whose turn it is |
| `state` | `GameState` enum | `PLAYING`, `WIN`, or `DRAW` |
| `winning_line` | `Array` | Three `[row, col]` pairs when `state == WIN` |
| `get_cell(row, col)` | `→ int` | Returns `Player.NONE / X / O` |
| `make_move(row, col)` | `→ bool` | Places a token; returns `false` if invalid |
| `clone()` | `→ GameBoard` | Deep copy used by minimax tree search |
| `empty_cells()` | `→ Array` | List of `[row, col]` pairs still available |
| `reset()` | `void` | Clears the board for a new round |

### `AI.gd` — opponent logic
A stateless `Reference` class. Never mutates the board it receives — always clones first.

**Three difficulty levels:**

| Level | Behaviour |
|-------|-----------|
| `EASY` | Picks a random empty cell every time |
| `MEDIUM` | Uses full minimax 60% of the time; random 40% (beatable) |
| `HARD` | Alpha-beta pruned minimax — optimal and unbeatable |

**API:**
```gdscript
var move: Array = AI.pick_move(board, AI.Difficulty.HARD, GameBoard.Player.O)
# move == [row, col], or [] if board is full
```

**How minimax works:**  
`_minimax()` recursively explores every possible future board state.  
Each terminal state is scored: `+10` if the AI wins, `-10` if it loses, `0` for a draw.  
Alpha-beta pruning skips branches that can't possibly improve the result, keeping it fast.

### `Main.gd` — UI controller
Owns one `GameBoard` per round. All DOM/node updates happen here and nowhere else.

Key responsibilities:
- On `_ready`: indexes the 9 cell buttons, connects all signals.
- `_on_cell_pressed(index)`: validates the move, refreshes visuals, schedules AI move if needed.
- `_schedule_ai_move()`: disables input, shows a brief "thinking" delay, then calls `AI.pick_move()`.
- `_refresh_*()` helpers: sync labels, cell colours, score, and turn dots after every state change.
- Mode (`_mode`) and difficulty (`_difficulty`) survive round resets; scores reset on mode/difficulty change.

---

## Running in the editor

1. Install **Godot 3.5** (not Godot 4 — uses Godot 3 GDScript syntax).
2. `File → Open Project → select this folder`.
3. Press **F5** to run.

---

## Exporting to HTML5

1. `Project → Export → Add → HTML5`.
2. Set export path to `export/index.html`.
3. Click **Export Project**.
4. Host the `export/` folder on any static server (Netlify, Vercel, GitHub Pages, itch.io).

### Pre-built deployment

`export/index.html` is a **standalone single-file HTML5 port** — architecturally identical:

- `class GameBoard` — direct JavaScript port of `GameBoard.gd` (same API, same `WIN_LINES`, same `_evaluate` logic).
- `class AI` — direct port of `AI.gd` (same three difficulty levels, same alpha-beta minimax with the same score convention).
- `class Main` — direct port of `Main.gd` that drives the DOM.

Open this file locally in any browser — no server required.

---

## Game rules

- Two modes: **2 Players** (local co-op) and **VS Computer** (you play X, AI plays O).
- In VS Computer mode, three difficulty levels: Easy, Medium, Hard.
- X always goes first.
- First to place three in a row (horizontal, vertical, or diagonal) wins.
- Board full with no winner → draw.
- Winning cells highlighted in green.
- Score persists across rounds; resets when you change mode or difficulty.

---

## Extending the project

**Change who goes first**  
In `Main.gd`, `_start_new_round()` always sets `_board.current_player = Player.X`.  
Add a flag to alternate or let the player choose.

**Let the player choose their side**  
Add a toggle in the mode bar for X / O. Set `_ai_player` accordingly in `Main.gd`.  
If the AI plays X, call `_schedule_ai_move()` at the end of `_start_new_round()`.

**Add sound**  
Add an `AudioStreamPlayer` node to `Main.tscn` and call `play()` from  
`_on_cell_pressed` and `_on_round_ended`.

**Add animations**  
Replace the `StyleBoxFlat` colour changes in `_set_button_color()` with  
a short `Tween` to animate the background transition.
