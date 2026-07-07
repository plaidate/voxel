-- Vault: input. D-pad moves, crank aims the sword (docked: follows
-- movement), A swings and leaps, B drops a bomb. Jump shares the sword
-- button because it is the only action safe to co-trigger -- a bomb sharing
-- a button would hurt the player, so it keeps B to itself.

Input = {
    state = { mx = 0, my = 0, aim = nil, swing = false, bomb = false, jump = false, confirm = false },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mx, s.my, s.aim, s.swing, s.bomb = 0, 0, nil, false, false
        s.confirm = State.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    s.mx, s.my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then s.my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.my = 1 end
    s.swing = pd.buttonJustPressed(pd.kButtonA)
    s.jump = s.swing -- A leaps too; bomb can't share a button (self-damage)
    s.bomb = pd.buttonJustPressed(pd.kButtonB)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
    if not pd.isCrankDocked() then
        s.aim = math.rad(pd.getCrankPosition() - 90)
    elseif s.mx ~= 0 or s.my ~= 0 then
        s.aim = math.atan(s.my, s.mx)
    else
        s.aim = nil
    end
end
