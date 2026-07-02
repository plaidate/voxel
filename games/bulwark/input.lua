-- Bulwark: input. Build phase: d-pad steps the cursor (hold to repeat),
-- the crank turns the piece in 90-degree detents (B also turns), A
-- places. Siege phase: crank aims the keep cannon, hold A runs the power
-- meter, release fires — the same scheme as Lob. The smoke autopilot only
-- advances screens; the game drives itself in smoke builds.

Input = {
    state = {
        mvx = 0, mvy = 0, rot = 0, place = false,
        aim = nil, chargeStart = false, charging = false, fire = false,
        confirm = false,
    },
}

local repT = 0
local crankAcc = 0
local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mvx, s.mvy, s.rot, s.place = 0, 0, 0, false
        s.aim, s.chargeStart, s.charging, s.fire = nil, false, false, false
        s.confirm = State.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    -- cursor steps: immediate on press, repeating while held
    local held = pd.buttonIsPressed(pd.kButtonLeft) or pd.buttonIsPressed(pd.kButtonRight)
        or pd.buttonIsPressed(pd.kButtonUp) or pd.buttonIsPressed(pd.kButtonDown)
    repT = held and repT + 1 or 0
    local rep = repT > 8 and repT % 4 == 0
    s.mvx, s.mvy = 0, 0
    if pd.buttonJustPressed(pd.kButtonLeft) or (rep and pd.buttonIsPressed(pd.kButtonLeft)) then s.mvx = -1 end
    if pd.buttonJustPressed(pd.kButtonRight) or (rep and pd.buttonIsPressed(pd.kButtonRight)) then s.mvx = 1 end
    if pd.buttonJustPressed(pd.kButtonUp) or (rep and pd.buttonIsPressed(pd.kButtonUp)) then s.mvy = -1 end
    if pd.buttonJustPressed(pd.kButtonDown) or (rep and pd.buttonIsPressed(pd.kButtonDown)) then s.mvy = 1 end
    -- crank: detent rotation for the build phase, absolute aim for siege
    s.rot = 0
    crankAcc = crankAcc + pd.getCrankChange()
    while crankAcc >= 90 do
        s.rot = s.rot + 1
        crankAcc = crankAcc - 90
    end
    while crankAcc <= -90 do
        s.rot = s.rot - 1
        crankAcc = crankAcc + 90
    end
    if pd.buttonJustPressed(pd.kButtonB) then s.rot = s.rot + 1 end
    s.aim = nil
    if not pd.isCrankDocked() then
        s.aim = math.rad(pd.getCrankPosition() - 90)
    end
    s.place = pd.buttonJustPressed(pd.kButtonA)
    s.chargeStart = pd.buttonJustPressed(pd.kButtonA)
    s.charging = pd.buttonIsPressed(pd.kButtonA)
    s.fire = pd.buttonJustReleased(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
end
