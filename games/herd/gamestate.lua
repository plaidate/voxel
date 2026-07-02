-- Herd: game state. mode is "title", "play" or "over"; phase is "banner"
-- (level intro / clear) or "run".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.level = 1
    State.phase = "banner"
    State.phaseT = 0
    State.banner = ""
    State.timer = Config.LEVEL_T
    State.saved = 0
    State.dead = 0
    State.spawned = 0
    State.quota = Config.QUOTA_BASE
    State.blasts = Config.BLASTS
    State.rate = 1.0
    State.spawnT = 0
    State.digCd = 0
    State.curX, State.curY = 30, 32
    State.reason = ""
end

State.reset()
