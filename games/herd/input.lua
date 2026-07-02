-- Herd: input. D-pad moves the dig cursor (hold to repeat), A digs, B
-- blasts, and the crank is the release-rate dial — wind it up to pour
-- sheep out faster. The smoke autopilot only advances screens; the game
-- drives itself in smoke builds.

Input = {
    state = {
        mvx = 0, mvy = 0, dig = false, blast = false,
        rate = nil, confirm = false,
    },
}

local repT = 0
local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mvx, s.mvy, s.dig, s.blast, s.rate = 0, 0, false, false, nil
        s.confirm = State.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    local held = pd.buttonIsPressed(pd.kButtonLeft) or pd.buttonIsPressed(pd.kButtonRight)
        or pd.buttonIsPressed(pd.kButtonUp) or pd.buttonIsPressed(pd.kButtonDown)
    repT = held and repT + 1 or 0
    local rep = repT > 6 and repT % 2 == 0
    s.mvx, s.mvy = 0, 0
    if pd.buttonJustPressed(pd.kButtonLeft) or (rep and pd.buttonIsPressed(pd.kButtonLeft)) then s.mvx = -1 end
    if pd.buttonJustPressed(pd.kButtonRight) or (rep and pd.buttonIsPressed(pd.kButtonRight)) then s.mvx = 1 end
    if pd.buttonJustPressed(pd.kButtonUp) or (rep and pd.buttonIsPressed(pd.kButtonUp)) then s.mvy = -1 end
    if pd.buttonJustPressed(pd.kButtonDown) or (rep and pd.buttonIsPressed(pd.kButtonDown)) then s.mvy = 1 end
    s.dig = pd.buttonIsPressed(pd.kButtonA)
    s.blast = pd.buttonJustPressed(pd.kButtonB)
    s.rate = nil
    if not pd.isCrankDocked() then
        -- crank angle maps straight onto the release-rate dial
        s.rate = Config.RATE_MIN
            + (pd.getCrankPosition() / 360) * (Config.RATE_MAX - Config.RATE_MIN)
    end
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
end
