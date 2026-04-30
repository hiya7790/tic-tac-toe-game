from enum import Enum
from typing import List, Optional

class Player(str, Enum):
    NONE = ""
    X = "X"
    O = "O"

class GameState(str, Enum):
    PLAYING = "PLAYING"
    WIN = "WIN"
    DRAW = "DRAW"

class GameBoard:
    WIN_LINES = [
        [[0,0],[0,1],[0,2]], [[1,0],[1,1],[1,2]], [[2,0],[2,1],[2,2]],  # rows
        [[0,0],[1,0],[2,0]], [[0,1],[1,1],[2,1]], [[0,2],[1,2],[2,2]],  # cols
        [[0,0],[1,1],[2,2]], [[0,2],[1,1],[2,0]],                        # diags
    ]

    def __init__(self):
        self.cells = [Player.NONE] * 9
        self.current_player = Player.X
        self.state = GameState.PLAYING
        self.winning_line: List[List[int]] = []

    def reset(self):
        self.cells = [Player.NONE] * 9
        self.current_player = Player.X
        self.state = GameState.PLAYING
        self.winning_line = []

    def get_cell(self, row: int, col: int) -> Player:
        return self.cells[row * 3 + col]

    def make_move(self, row: int, col: int, player: Player) -> bool:
        if self.state != GameState.PLAYING:
            return False
        if player != self.current_player:
            return False
        
        idx = row * 3 + col
        if self.cells[idx] != Player.NONE:
            return False
            
        self.cells[idx] = self.current_player
        self._evaluate()
        return True

    def _evaluate(self):
        for line in self.WIN_LINES:
            a = self.cells[line[0][0] * 3 + line[0][1]]
            b = self.cells[line[1][0] * 3 + line[1][1]]
            c = self.cells[line[2][0] * 3 + line[2][1]]
            if a != Player.NONE and a == b and b == c:
                self.state = GameState.WIN
                self.winning_line = line
                return

        has_empty = any(cell == Player.NONE for cell in self.cells)

        if not has_empty:
            self.state = GameState.DRAW
            return

        self.current_player = Player.O if self.current_player == Player.X else Player.X
        
    def clone(self):
        new_board = GameBoard()
        new_board.cells = self.cells.copy()
        new_board.current_player = self.current_player
        new_board.state = self.state
        new_board.winning_line = [line.copy() for line in self.winning_line]
        return new_board
        
    def empty_cells(self) -> List[tuple[int, int]]:
        return [(i // 3, i % 3) for i, c in enumerate(self.cells) if c == Player.NONE]

    def to_dict(self):
        return {
            "cells": [c.value for c in self.cells],
            "current_player": self.current_player.value,
            "state": self.state.value,
            "winning_line": self.winning_line
        }

def _minimax(board: GameBoard, depth: int, is_maximizing: bool, ai_player: Player, alpha: int, beta: int) -> int:
    human_player = Player.X if ai_player == Player.O else Player.O
    
    if board.state == GameState.WIN:
        return 10 - depth if board.current_player == ai_player else -10 + depth
    elif board.state == GameState.DRAW:
        return 0
        
    if is_maximizing:
        best_score = -9999
        for (r, c) in board.empty_cells():
            sim_board = board.clone()
            sim_board.make_move(r, c, ai_player)
            score = _minimax(sim_board, depth + 1, False, ai_player, alpha, beta)
            best_score = max(score, best_score)
            alpha = max(alpha, best_score)
            if beta <= alpha:
                break
        return best_score
    else:
        best_score = 9999
        for (r, c) in board.empty_cells():
            sim_board = board.clone()
            sim_board.make_move(r, c, human_player)
            score = _minimax(sim_board, depth + 1, True, ai_player, alpha, beta)
            best_score = min(score, best_score)
            beta = min(beta, best_score)
            if beta <= alpha:
                break
        return best_score

def ai_pick_move(board: GameBoard, ai_player: Player) -> Optional[tuple[int, int]]:
    empty = board.empty_cells()
    if not empty:
        return None
        
    best_score = -9999
    best_move = None
    
    for (r, c) in empty:
        sim_board = board.clone()
        sim_board.make_move(r, c, ai_player)
        score = _minimax(sim_board, 0, False, ai_player, -9999, 9999)
        if score > best_score:
            best_score = score
            best_move = (r, c)
            
    return best_move
