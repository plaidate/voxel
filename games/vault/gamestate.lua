-- Vault: game state. The mode lives in Kit.mode ("title", "play" or
-- "over"); Kit.modeT > 0 is the room banner (in play) or the game-over
-- input lockout. session carries the dungeon's per-room state and is
-- mirrored to the datastore so a run can be continued after relaunch.

State = {}

function State.reset()
    State.hp = Config.MAX_HP
    State.keys = 0
    State.bombs = Config.START_BOMBS
    State.room = "A"
    State.banner = ""
    State.reason = ""
    State.won = false
    State.session = { rooms = {}, visited = { A = true } }
end

State.reset()
