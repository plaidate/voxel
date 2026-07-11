-- Summit: game state. The mode lives in Kit.mode ("title", "play" or
-- "over"); Kit.modeT > 0 during play is the round banner.

State = {}

function State.reset()
    State.score = 0
    State.round = 1
    State.banner = ""
    State.reason = ""
    State.erodeIn = Config.EROSION_T
    State.newBest = false
end

State.reset()
