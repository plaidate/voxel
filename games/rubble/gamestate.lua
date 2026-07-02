-- Rubble: run state. mode is "title", "play" or "dead".

State = { mode = "title" }

function State.reset()
    State.score = 0
    State.wave = 0
    State.hp = Config.MAX_HP
    State.t = 0
end

State.reset()
