-- Excavate: input. D-pad moves, the crank aims the pick (docked: aim
-- follows movement), A digs (hold to keep digging), B hops. The smoke
-- autopilot lives in game.lua.

Input = {
    state = { mx = 0, my = 0, aim = nil, dig = false, jump = false, confirm = false },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        apFrame = apFrame + 1
        s.mx, s.my, s.aim, s.dig, s.jump = 0, 0, nil, false, false
        s.confirm = Kit.mode ~= "play" and apFrame % 30 == 0
        return
    end
    local pd = playdate
    s.mx, s.my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then s.my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.my = 1 end
    s.dig = pd.buttonIsPressed(pd.kButtonA)
    s.jump = pd.buttonJustPressed(pd.kButtonB)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
    if not pd.isCrankDocked() then
        s.aim = math.rad(pd.getCrankPosition() - 90)
    elseif s.mx ~= 0 or s.my ~= 0 then
        s.aim = math.atan(s.my, s.mx)
    else
        s.aim = nil
    end
end
