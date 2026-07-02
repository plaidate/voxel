-- Marble: game state. mode is "title", "play" or "over"; phase is
-- "banner" or "run".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.course = 1
    State.marbles = Config.MARBLES
    State.timer = Config.COURSE_T
    State.phase = "banner"
    State.phaseT = 0
    State.banner = ""
    State.reason = ""
end

State.reset()
