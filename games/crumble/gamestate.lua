-- Crumble: run state. mode is "title", "play" or "dead".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.hp = Config.MAX_HP
    State.t = 0
    State.slimeLevel = 0
    State.riseIn = Config.SLIME_T0
    State.riseInterval = Config.SLIME_T0
    State.shake = 0
end

State.reset()
