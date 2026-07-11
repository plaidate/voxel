-- Lob: input. The crank rotates the mortar's aim (d-pad left/right as a
-- docked fallback); holding A runs the oscillating power meter and
-- releasing A fires at whatever the meter reads. In smoke builds the game
-- itself aims the player's shots (same solver as the foe), so the
-- autopilot only advances title/game-over screens.

Input = {
    state = {
        aim = nil, rotL = false, rotR = false,
        chargeStart = false, fire = false,
        confirm = false,
    },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.aim, s.rotL, s.rotR = nil, false, false
        s.chargeStart, s.fire = false, false
        s.confirm = Kit.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    s.aim = nil
    if not pd.isCrankDocked() then
        -- crank up = aim away from the viewer
        s.aim = math.rad(pd.getCrankPosition() - 90)
    end
    s.rotL = pd.buttonIsPressed(pd.kButtonLeft)
    s.rotR = pd.buttonIsPressed(pd.kButtonRight)
    s.chargeStart = pd.buttonJustPressed(pd.kButtonA)
    s.fire = pd.buttonJustReleased(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
end
