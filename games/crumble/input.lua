-- Crumble: input. D-pad moves, B hops, the crank winds the spring and A
-- releases it (uncharged A = plain hop). The smoke autopilot chases gems,
-- keeps the spring wound, and boings when it gets stuck.

Input = {
    state = { mx = 0, my = 0, jump = false, spring = false, charge = 0, confirm = false },
}

local ap = { frame = 0, lastX = 0, lastY = 0, moved = 0, win = 0 }

local function autopilot(s)
    ap.frame = ap.frame + 1
    s.confirm = Kit.mode ~= "play" and ap.frame % 30 == 0
    s.charge = 0.04
    s.jump = false
    s.spring = false
    local p = Game.player
    if not p then return end
    -- head for the nearest gem
    local best, bd = nil, math.huge
    for _, gm in ipairs(Game.gems) do
        local d = (gm.x - p.x) ^ 2 + (gm.y - p.y) ^ 2
        if d < bd then bd, best = d, gm end
    end
    s.mx, s.my = 0, 0
    if best then
        local dx, dy = best.x - p.x, best.y - p.y
        s.mx = (dx > 1.5 and 1) or (dx < -1.5 and -1) or 0
        s.my = (dy > 1.5 and 1) or (dy < -1.5 and -1) or 0
        -- gem above and nearby -> spring up to it once charged
        if p.grounded and p.charge > 0.5 and best.z > p.z + 1
            and math.abs(dx) < 6 and math.abs(dy) < 6 then
            s.spring = true
        end
    end
    -- stuck for ~1.5s while trying to move -> spring jump
    ap.moved = ap.moved + math.abs(p.x - ap.lastX) + math.abs(p.y - ap.lastY)
    ap.lastX, ap.lastY = p.x, p.y
    ap.win = ap.win + 1
    if ap.win >= 45 then
        if ap.moved < 1.5 and (s.mx ~= 0 or s.my ~= 0) then
            s.spring = true
        end
        ap.win, ap.moved = 0, 0
    end
    if math.random() < 0.008 then s.jump = true end
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
    s.jump = pd.buttonJustPressed(pd.kButtonB)
    s.spring = pd.buttonJustPressed(pd.kButtonA)
    s.confirm = pd.buttonJustPressed(pd.kButtonA)
    s.charge = math.abs(pd.getCrankChange()) / 720
end
