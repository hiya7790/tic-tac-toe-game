import asyncio
import websockets
import json

async def test():
    uri = "ws://localhost:18563/ws"
    try:
        async with websockets.connect(uri) as ws1:
            print("Client 1 connected")
            # Create room
            await ws1.send(json.dumps({"action": "create_room"}))
            response = await ws1.recv()
            data1 = json.loads(response)
            print("Client 1 received:", data1)
            room_id = data1["room_id"]
            
            async with websockets.connect(uri) as ws2:
                print("Client 2 connected")
                # Join room
                await ws2.send(json.dumps({"action": "join_room", "room_id": room_id}))
                
                # Should get room_joined
                response = await ws2.recv()
                print("Client 2 received:", json.loads(response))
                
                # Client 1 should get game_start
                response = await ws1.recv()
                print("Client 1 received game_start:", json.loads(response))
                
                # Client 2 should get game_start
                response = await ws2.recv()
                print("Client 2 received game_start:", json.loads(response))
                
                # Move
                await ws1.send(json.dumps({"action": "make_move", "row": 0, "col": 0}))
                
                # Client 1 gets state update
                print("Client 1 state update:", json.loads(await ws1.recv()))
                
                # Client 2 gets state update
                print("Client 2 state update:", json.loads(await ws2.recv()))
                
                print("Test passed!")
                
    except Exception as e:
        print("Test failed:", e)

if __name__ == "__main__":
    asyncio.run(test())
