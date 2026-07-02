-- Bulwark: game state. mode is "title", "play" or "over"; phase cycles
-- "banner" -> "build" -> "banner" -> "siege" -> ...

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.round = 0
    State.keepHp = Config.KEEP_HP
    State.keepFlash = 0
    State.phase = "banner"
    State.nextPhase = "build"
    State.phaseT = 0
    State.banner = ""
    State.curX, State.curY = 6, 16
    State.pieceIdx, State.pieceRot = 1, 0
    State.reason = ""
    State.won = false
end

State.reset()
