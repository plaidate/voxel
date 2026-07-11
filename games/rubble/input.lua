-- Rubble: input. D-pad moves, crank aims (docked: aim follows movement),
-- A fires (hold for autofire), B jumps. In smoke builds the autopilot
-- wanders the arena and auto-aims at the nearest grub.

Input = {
    state = { mx = 0, my = 0, aim = nil, fire = false, jump = false, confirm = false },
}

local ap = { frame = 0, dirT = 0, tx = Vox.W / 2, ty = Vox.D / 2 }

local function autopilot(s)
    ap.frame = ap.frame + 1
    s.confirm = Kit.mode ~= "play" and ap.frame % 30 == 0
    -- cease fire from wave 4 so the grubs win and the death path gets tested
    s.fire = State.wave < 4
    s.jump = math.random() < 0.01
    local p = Game.player
    if not p then return end
    ap.dirT = ap.dirT - 1
    if ap.dirT <= 0 then
        ap.dirT = 60 + math.random(60)
        ap.tx = 14 + math.random() * (Vox.W - 28)
        ap.ty = 14 + math.random() * (Vox.D - 28)
    end
    local dx, dy = ap.tx - p.x, ap.ty - p.y
    s.mx = (dx > 2 and 1) or (dx < -2 and -1) or 0
    s.my = (dy > 2 and 1) or (dy < -2 and -1) or 0
    local best, bd = nil, math.huge
    for _, e in ipairs(Game.enemies) do
        local d = (e.x - p.x) ^ 2 + (e.y - p.y) ^ 2
        if d < bd then bd, best = d, e end
    end
    if best then
        s.aim = math.atan(best.y - p.y, best.x - p.x)
    else
        s.aim = nil
    end
end

function Input.poll()
    local s = Input.state
    if Harness.enabled then
        autopilot(s)
        return
    end
    local pd = playdate
    s.mx, s.my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then s.mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then s.mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then s.my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then s.my = 1 end
    s.fire = pd.buttonIsPressed(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
    s.jump = pd.buttonJustPressed(pd.kButtonB)
    if not pd.isCrankDocked() then
        -- crank up aims away from the viewer
        s.aim = math.rad(pd.getCrankPosition() - 90)
    elseif s.mx ~= 0 or s.my ~= 0 then
        s.aim = math.atan(s.my, s.mx)
    else
        s.aim = nil
    end
end
