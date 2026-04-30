import string
import random
from typing import Dict
from fastapi import WebSocket
from game_logic import GameBoard, Player

class Room:
    def __init__(self, room_id: str, is_bot_room: bool = False):
        self.room_id = room_id
        self.players: Dict[str, WebSocket] = {}  # "X" -> WebSocket, "O" -> WebSocket
        self.board = GameBoard()
        self.is_bot_room = is_bot_room
        
    def is_full(self):
        if self.is_bot_room:
            return "X" in self.players
        return len(self.players) >= 2

    def add_player(self, websocket: WebSocket) -> Player:
        if "X" not in self.players:
            self.players["X"] = websocket
            return Player.X
        elif "O" not in self.players:
            self.players["O"] = websocket
            return Player.O
        return Player.NONE

    def remove_player(self, websocket: WebSocket):
        keys_to_remove = []
        for p_id, ws in self.players.items():
            if ws == websocket:
                keys_to_remove.append(p_id)
        for k in keys_to_remove:
            del self.players[k]
            
    def get_player_side(self, websocket: WebSocket) -> Player:
        for p_id, ws in self.players.items():
            if ws == websocket:
                return Player(p_id)
        return Player.NONE

class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, Room] = {}

    def _generate_room_id(self, length=4) -> str:
        characters = string.ascii_uppercase + string.digits
        return ''.join(random.choice(characters) for _ in range(length))

    def create_room(self, is_bot_room: bool = False) -> Room:
        room_id = self._generate_room_id()
        while room_id in self.rooms:
            room_id = self._generate_room_id()
        room = Room(room_id, is_bot_room)
        self.rooms[room_id] = room
        return room

    def get_room(self, room_id: str) -> Room | None:
        return self.rooms.get(room_id)

    def delete_room(self, room_id: str):
        if room_id in self.rooms:
            del self.rooms[room_id]

    async def broadcast_to_room(self, room: Room, message: dict):
        for websocket in list(room.players.values()):
            try:
                await websocket.send_json(message)
            except Exception:
                pass
