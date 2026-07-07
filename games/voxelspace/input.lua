-- Voxelspace: input. Crank or left/right steers, up/down climbs and
-- dives, A (held) boosts, B rerolls the terrain.

Input = {
    state = { dturn = 0, crank = 0, climb = 0, boost = false, regen = false, confirm = false },
}

local apFrame = 0

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        -- autopilot: lazy S-curves, cycling climb, periodic boost/reroll
        apFrame = apFrame + 1
        s.confirm = State.mode == "title" and apFrame % 30 == 0
        s.crank = 0
        s.dturn = math.sin(apFrame * 0.008)
        s.climb = (apFrame // 240) % 3 - 1
        s.boost = apFrame % 600 > 450
        s.regen = apFrame % 1200 == 900
        return
    end
    local pd = playdate
    s.dturn = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.dturn = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.dturn = 1 end
    s.crank = pd.getCrankChange()
    s.climb = 0
    if pd.buttonIsPressed(pd.kButtonUp) then s.climb = 1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.climb = -1 end
    s.boost = pd.buttonIsPressed(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
    s.regen = pd.buttonJustPressed(pd.kButtonB)
end
