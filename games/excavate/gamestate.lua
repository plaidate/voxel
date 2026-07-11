-- Excavate: game state. The mode lives in Kit.mode ("title", "play" or
-- "over"); Kit.modeT > 0 is the shift banner (in play) or the game-over
-- input lockout.

State = {}

function State.reset()
    State.score = 0
    State.level = 1
    State.hp = Config.MAX_HP
    State.left = 0
    State.timer = Config.SHIFT_T
    State.banner = ""
    State.reason = ""
end

State.reset()
