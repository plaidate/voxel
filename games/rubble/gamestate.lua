-- Rubble: run state. Kit.mode is "title", "play" or "dead".

State = {}

function State.reset()
    State.score = 0
    State.wave = 0
    State.hp = Config.MAX_HP
    State.t = 0
    State.newBest = false
end

State.reset()
