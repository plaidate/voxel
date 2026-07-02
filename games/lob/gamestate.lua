-- Lob: match state. mode is "title", "play" or "over"; phase is the
-- turn machine: "banner" -> "aim" -> "flight" -> "resolve" -> ...

State = { mode = "title" }

function State.reset()
    State.youWins, State.foeWins = 0, 0
    State.round = 0
    State.aiErr = Config.AI_ERR0
    State.phase = "banner"
    State.phaseT = 0
    State.turn = "you"
    State.wind = 0
    State.banner = ""
    State.youWon = false
end

State.reset()
