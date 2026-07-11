-- Marble: game state. The mode lives in Kit.mode ("title", "play" or
-- "over"); Kit.modeT > 0 during play is the course banner.

State = {}

function State.reset()
    State.score = 0
    State.course = 1
    State.marbles = Config.MARBLES
    State.timer = Config.COURSE_T
    State.banner = ""
    State.reason = ""
    State.newBest = false
end

State.reset()
