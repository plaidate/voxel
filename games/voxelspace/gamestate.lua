-- Voxelspace: state. The mode lives in Kit.mode ("title" or "fly"); the
-- terrain itself lives in Map (game.lua).

State = {}

function State.reset()
    State.x, State.y = 128, 128
    State.alt = 80
    State.ang = 0
    State.pitch = 0
    State.dist = 0
    State.seed = playdate.getSecondsSinceEpoch()
end

State.reset()
