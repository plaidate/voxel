-- Marble: input. D-pad steers, the crank winds the boost, A releases it.

Input = {
    state = { mx = 0, my = 0, charge = 0, boost = false, confirm = false },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mx, s.my, s.charge, s.boost = 0, 0, 0, false
        s.confirm = State.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    s.mx, s.my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then s.my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.my = 1 end
    s.charge = math.abs(pd.getCrankChange()) / 720
    s.boost = pd.buttonJustPressed(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
end
