-- Summit: game state. mode is "title", "play" or "over"; phase is
-- "banner" or "run".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.round = 1
    State.phase = "banner"
    State.phaseT = 0
    State.banner = ""
    State.erodeIn = Config.EROSION_T
end

State.reset()
