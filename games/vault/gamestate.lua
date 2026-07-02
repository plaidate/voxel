-- Vault: game state. mode is "title", "play" or "over". session carries
-- the dungeon's per-room state and is mirrored to the datastore so a run
-- can be continued after relaunch.

State = { mode = "title" }

function State.reset()
    State.hp = Config.MAX_HP
    State.keys = 0
    State.bombs = Config.START_BOMBS
    State.room = "A"
    State.phase = "banner"
    State.phaseT = 0
    State.banner = ""
    State.reason = ""
    State.won = false
    State.session = { rooms = {}, visited = { A = true } }
end

State.reset()
