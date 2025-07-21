from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import chess
import chess.engine
from typing import Optional
import uvicorn
import json
import time
import os
import asyncio
import platform

app = FastAPI(title="Global Chess API with Stockfish")

# CORS for cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store active game states
active_games = {}

# Initialize Stockfish engine with platform-specific handling
STOCKFISH_PATH = os.getenv("STOCKFISH_PATH", "stockfish")  # Default for Render
if platform.system() == "Windows":
    # Workaround for Windows: Use a specific path or delay initialization
    engine = None  # Initialize on first use
else:
    engine = chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)

def get_engine():
    global engine
    if engine is None:
        # Initialize on demand for Windows or reinitialize if closed
        engine = chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)
    return engine

# Start a new game
@app.post("/start_game")
async def start_game(game_id: Optional[str] = None):
    if not game_id:
        game_id = str(hash(str(active_games) + str(time.time())))[:8]  # Unique ID
    board = chess.Board()
    active_games[game_id] = {"board": board, "turn": True, "difficulty": 50}  # Default difficulty 50
    return {"game_id": game_id, "fen": board.fen(), "status": "started", "difficulty": 50}

# Set or update difficulty (0-100)
@app.post("/set_difficulty")
async def set_difficulty(game_id: str, difficulty: int):
    if game_id not in active_games or difficulty < 0 or difficulty > 100:
        return {"status": "error", "message": "Invalid game or difficulty"}
    active_games[game_id]["difficulty"] = difficulty
    return {"status": "success", "difficulty": difficulty}

# Make a player move
@app.post("/make_move")
async def make_move(game_id: str, move: str):
    if game_id not in active_games:
        return {"status": "error", "message": "Game not found"}
    game = active_games[game_id]
    board = game["board"]
    try:
        move_obj = chess.Move.from_uci(move)
        if move_obj in board.legal_moves and game["turn"]:
            board.push(move_obj)
            game["turn"] = False  # Switch to AI turn
            status = "ongoing"
            if board.is_checkmate():
                status = "checkmate"
            elif board.is_stalemate():
                status = "stalemate"
            return {"fen": board.fen(), "status": status, "turn": "ai", "player_move": move}
        return {"status": "invalid", "message": "Illegal move"}
    except ValueError:
        return {"status": "error", "message": "Invalid move format"}

# Get AI move using Stockfish based on difficulty (0-100)
@app.post("/get_ai_move")
async def get_ai_move(game_id: str):
    if game_id not in active_games:
        return {"status": "error", "message": "Game not found"}
    game = active_games[game_id]
    board = game["board"]
    if game["turn"]:  # Should be False (AI's turn)
        return {"status": "error", "message": "Not AI's turn"}
    difficulty = game["difficulty"] / 100  # Normalize to 0-1
    engine = get_engine()

    # Configure Stockfish based on difficulty
    time_limit = 0.1 + (difficulty * 2)  # 0.1s (easy) to 2.1s (hard)
    if difficulty < 0.33:  # 0-32: Easy (short think)
        result = await engine.play(board, chess.engine.Limit(time=time_limit), async_callback=lambda *args: None)
    elif difficulty < 0.66:  # 33-65: Medium (moderate think)
        result = await engine.play(board, chess.engine.Limit(time=time_limit, depth=10), async_callback=lambda *args: None)
    else:  # 66-100: Hard/Impossible (deep think)
        result = await engine.play(board, chess.engine.Limit(time=time_limit, depth=15), async_callback=lambda *args: None)

    ai_move = result.move
    board.push(ai_move)
    game["turn"] = True  # Switch back to player
    status = "ongoing"
    if board.is_checkmate():
        status = "checkmate"
    elif board.is_stalemate():
        status = "stalemate"
    return {"move": ai_move.uci(), "fen": board.fen(), "status": status, "turn": "player", "ai_move": ai_move.uci()}

# WebSocket for real-time updates
@app.websocket("/ws/{game_id}")
async def websocket_endpoint(websocket: WebSocket, game_id: str):
    await websocket.accept()
    try:
        while True:
            if game_id in active_games and not active_games[game_id]["turn"]:
                board = active_games[game_id]["board"]
                await websocket.send_text(json.dumps({"fen": board.fen(), "status": "ai_thinking"}))
                response = await get_ai_move(game_id)
                await websocket.send_text(json.dumps(response))
            await websocket.receive_text()  # Keep alive
    except WebSocketDisconnect:
        if game_id in active_games:
            del active_games[game_id]
    finally:
        if 'engine' in globals() and engine is not None:
            engine.quit()  # Clean up engine

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)