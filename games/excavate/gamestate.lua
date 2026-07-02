-- Excavate: game state. mode is "title", "play" or "over"; phase is
-- "banner" or "run".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.level = 1
    State.hp = Config.MAX_HP
    State.left = 0
    State.timer = Config.SHIFT_T
    State.phase = "banner"
    State.phaseT = 0
    State.banner = ""
    State.reason = ""
end

State.reset()
