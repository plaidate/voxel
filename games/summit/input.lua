-- Summit: input. D-pad moves, A shoves (a full crank-wound meter turns
-- the next A into a radial spin), B jumps between terraces.

Input = {
    state = { mx = 0, my = 0, act = false, jump = false, charge = 0, confirm = false },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mx, s.my, s.act, s.jump, s.charge = 0, 0, false, false, 0
        s.confirm = Kit.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    s.mx, s.my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then s.my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.my = 1 end
    s.act = pd.buttonJustPressed(pd.kButtonA)
    s.jump = pd.buttonJustPressed(pd.kButtonB)
    s.charge = math.abs(pd.getCrankChange()) / (360 * Config.SPIN_RATE)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
end
