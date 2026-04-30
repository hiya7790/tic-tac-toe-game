import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from connection_manager import ConnectionManager
from game_logic import Player, ai_pick_move

app = FastAPI(title="Tic-Tac-Toe Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

manager = ConnectionManager()

@app.get("/")
def health_check():
    return {"status": "ok", "message": "Tic-Tac-Toe backend is running!"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    current_room = None
    
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
            except json.JSONDecodeError:
                await websocket.send_json({"error": "Invalid JSON"})
                continue
                
            action = message.get("action")
            
            if action == "create_room":
                if current_room:
                    current_room.remove_player(websocket)
                current_room = manager.create_room()
                player_side = current_room.add_player(websocket)
                await websocket.send_json({
                    "type": "room_created",
                    "room_id": current_room.room_id,
                    "player": player_side.value
                })
                
            elif action == "create_bot_room":
                if current_room:
                    current_room.remove_player(websocket)
                current_room = manager.create_room(is_bot_room=True)
                player_side = current_room.add_player(websocket)
                await websocket.send_json({
                    "type": "room_created",
                    "room_id": current_room.room_id,
                    "player": player_side.value
                })
                # Immediately start game since bot is the other player
                await manager.broadcast_to_room(current_room, {
                    "type": "game_start",
                    "starting_player": current_room.board.current_player.value,
                    "board": current_room.board.to_dict()
                })
                
            elif action == "join_room":
                room_id = message.get("room_id")
                if not room_id:
                    await websocket.send_json({"error": "room_id required"})
                    continue
                    
                room = manager.get_room(room_id.upper())
                if not room:
                    await websocket.send_json({"error": "Room not found"})
                    continue
                if room.is_full():
                    await websocket.send_json({"error": "Room is full"})
                    continue
                    
                if current_room:
                    current_room.remove_player(websocket)
                    
                current_room = room
                player_side = current_room.add_player(websocket)
                
                await websocket.send_json({
                    "type": "room_joined",
                    "room_id": current_room.room_id,
                    "player": player_side.value
                })
                
                # If room is full, start the game
                if current_room.is_full():
                    await manager.broadcast_to_room(current_room, {
                        "type": "game_start",
                        "starting_player": current_room.board.current_player.value,
                        "board": current_room.board.to_dict()
                    })
                    
            elif action == "make_move":
                if not current_room:
                    await websocket.send_json({"error": "Not in a room"})
                    continue
                    
                row = message.get("row")
                col = message.get("col")
                
                if row is None or col is None:
                    await websocket.send_json({"error": "row and col required"})
                    continue
                    
                player_side = current_room.get_player_side(websocket)
                if player_side == Player.NONE:
                    await websocket.send_json({"error": "You are not a player in this room"})
                    continue
                    
                success = current_room.board.make_move(row, col, player_side)
                if not success:
                    await websocket.send_json({"error": "Invalid move"})
                    continue
                    
                # Broadcast updated state
                await manager.broadcast_to_room(current_room, {
                    "type": "state_update",
                    "board": current_room.board.to_dict(),
                    "last_move": {"row": row, "col": col, "player": player_side.value}
                })
                
                # If bot room and it's bot's turn, make bot move
                if current_room.is_bot_room and current_room.board.state == "PLAYING" and current_room.board.current_player == Player.O:
                    import asyncio
                    await asyncio.sleep(0.5) # Add a small delay for realism
                    move = ai_pick_move(current_room.board, Player.O)
                    if move:
                        current_room.board.make_move(move[0], move[1], Player.O)
                        await manager.broadcast_to_room(current_room, {
                            "type": "state_update",
                            "board": current_room.board.to_dict(),
                            "last_move": {"row": move[0], "col": move[1], "player": "O"}
                        })

            elif action == "restart":
                if not current_room:
                    continue
                current_room.board.reset()
                await manager.broadcast_to_room(current_room, {
                    "type": "game_restart",
                    "starting_player": current_room.board.current_player.value,
                    "board": current_room.board.to_dict()
                })
                
    except WebSocketDisconnect:
        if current_room:
            current_room.remove_player(websocket)
            # If the room is empty, clean it up
            if len(current_room.players) == 0:
                manager.delete_room(current_room.room_id)
            else:
                # Notify the other player
                import asyncio
                asyncio.create_task(manager.broadcast_to_room(current_room, {
                    "type": "player_disconnected"
                }))
