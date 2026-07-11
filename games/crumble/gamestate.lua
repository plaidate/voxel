-- Crumble: run state. The mode lives in Kit.mode ("title", "play" or
-- "dead"); Kit.modeT gates the restart on the death screen.

State = {}

function State.reset()
    State.score = 0
    State.hp = Config.MAX_HP
    State.t = 0
    State.slimeLevel = 0
    State.riseIn = Config.SLIME_T0
    State.riseInterval = Config.SLIME_T0
    State.newBest = false
end

State.reset()
