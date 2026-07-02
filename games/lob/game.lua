-- Lob: turn-based artillery. Two mortars on a hilly heightfield with a
-- central ridge; shells fly a 45-degree parabola bent by per-turn wind
-- and carve craters. The foe's aim solver brackets tighter every shot.

local snd = {
    fire = playdate.sound.synth.new(playdate.sound.kWaveTriangle),
    boom = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    hit = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
    turn = playdate.sound.synth.new(playdate.sound.kWaveSquare),
}

Game = {
    you = nil,
    foe = nil,
    shot = nil,
    parts = {},
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

Game.foeModel = VoxModel.fromLayers({
    { "1.1", "1.1" },
    { "111", "111" },
    { "111", "111" },
    { ".4.", ".4." },
})

local aiPending = nil

local function physZ(e, dt)
    VoxPhys.physZ(e, dt, Config.GRAVITY)
end

function Game.buildWorld()
    Vox.clear()
    local W, D = Vox.W, Vox.D
    local hmap = {}
    for i = 0, W * D - 1 do hmap[i] = 1.5 end
    local function bump(cx, cy, r, h)
        local r2 = r * r
        for x = math.max(0, cx - r), math.min(W - 1, cx + r) do
            for y = math.max(0, cy - r), math.min(D - 1, cy + r) do
                local d2 = ((x - cx) ^ 2 + (y - cy) ^ 2) / r2
                if d2 < 1 then
                    local i = y * W + x
                    hmap[i] = hmap[i] + h * (1 - d2)
                end
            end
        end
    end
    -- rolling hills
    for _ = 1, 10 do
        bump(math.random(6, W - 7), math.random(5, D - 6),
            math.random(6, 14), math.random(1, 4) + math.random())
    end
    -- central ridge blocks the flat shot and forces real lobs
    for _ = 1, 4 do
        bump(W // 2 + math.random(-6, 6), math.random(8, D - 9),
            math.random(5, 9), math.random(3, 6))
    end
    -- flat firing pads
    for _, p in ipairs({ { 12, D // 2 }, { W - 13, D // 2 } }) do
        for x = p[1] - 4, p[1] + 4 do
            for y = p[2] - 4, p[2] + 4 do
                hmap[y * W + x] = 2
            end
        end
    end
    for x = 0, W - 1 do
        for y = 0, D - 1 do
            local hh = math.floor(Util.clamp(hmap[y * W + x], 1, Vox.H - 3))
            -- only high ground gets bright caps so the white unit stays
            -- readable on the low hills
            local cap = hh >= 6 and 3 or 2
            for z = 0, hh - 1 do
                Vox.set(x, y, z, z == hh - 1 and cap or 2)
            end
        end
    end
    Vox.buildBG()
end

local function makeUnit(x, y, model, az)
    local u = {
        x = x + 0.5, y = y + 0.5, z = 0, vz = 0, hw = 1, grounded = true,
        hp = Config.MAX_HP, az = az, power = 0.5, model = model, flash = 0,
        charging = false, meterT = 0,
    }
    u.z = VoxPhys.groundAt(u.x, u.y, u.hw)
    return u
end

local function setPhase(ph, t, banner)
    State.phase = ph
    State.phaseT = t or 0
    if banner then State.banner = banner end
end

local function rollWind()
    State.wind = (math.random() * 2 - 1) * Config.WIND_MAX
end

function Game.startRound()
    Game.buildWorld()
    State.round = State.round + 1
    Game.you = makeUnit(12, Vox.D // 2, Game.playerModel, 0)
    Game.foe = makeUnit(Vox.W - 13, Vox.D // 2, Game.foeModel, math.pi)
    Game.shot = nil
    Game.parts = {}
    aiPending = nil
    rollWind()
    State.turn = (State.round % 2 == 1) and "you" or "foe"
    setPhase("banner", Config.BANNER_T, "ROUND " .. State.round)
end

function Game.startMatch()
    State.reset()
    State.mode = "play"
    Game.startRound()
end

function Game.init()
    Game.startMatch()
    State.mode = "title"
end

function Game.spawnPart(x, y, z, m)
    if #Game.parts > 40 then return end
    Game.parts[#Game.parts + 1] = {
        x = x, y = y, z = z,
        vx = (math.random() - 0.5) * 14,
        vy = (math.random() - 0.5) * 14,
        vz = math.random() * 10 + 4,
        t = 0.7 + math.random() * 0.4,
        m = m,
    }
end

-- launch offsets are Lob's; the flight math is the shared core integrator
local function launch(u, az, power)
    az = az or u.az
    power = power or u.power
    local v = Config.VMIN + power * (Config.VMAX - Config.VMIN)
    local ca, sa = math.cos(az), math.sin(az)
    return VoxProj.launch(u.x + ca * 2, u.y + sa * 2, u.z + 4.5,
        az, v, Config.ELEV_COS, Config.ELEV_SIN)
end

local function stepProj(p, dt)
    return VoxProj.step(p, dt, Config.GRAVITY, State.wind)
end

local function simImpact(u, az, power)
    local p = launch(u, az, power)
    for _ = 1, 300 do
        if stepProj(p, 1 / 30) then break end
    end
    return p.x, p.y
end

-- pick the best power for a straight azimuth at the target, then smear
-- both by err (the foe's err shrinks every shot: classic bracketing)
function Game.solveAim(u, tgt, err)
    local az = math.atan(tgt.y - u.y, tgt.x - u.x)
    local bestP, bestMiss = 0.5, math.huge
    for i = 0, 10 do
        local pow = i / 10
        local ix, iy = simImpact(u, az, pow)
        local miss = (ix - tgt.x) ^ 2 + (iy - tgt.y) ^ 2
        if miss < bestMiss then bestMiss, bestP = miss, pow end
    end
    local function n() return math.random() + math.random() - 1 end
    return az + n() * err * 0.03, Util.clamp(bestP + n() * err * 0.04, 0, 1)
end

function Game.fire(u)
    Game.shot = launch(u)
    snd.fire:playNote(131, 0.4, 0.15)
    Harness.count("shots")
    setPhase("flight", 0)
end

local function explode(x, y, z)
    local removed = Vox.carve(x, y, z, Config.CARVE_R)
    Harness.count("carved", #removed)
    snd.boom:playNote(80, 0.5, 0.3)
    for _ = 1, math.min(#removed, 10) do
        local v = removed[math.random(#removed)]
        Game.spawnPart(v[1], v[2], v[3], v[4])
    end
    for _ = 1, 6 do Game.spawnPart(x, y, z, 4) end
    for _, u in ipairs({ Game.you, Game.foe }) do
        local d = math.sqrt((u.x - x) ^ 2 + (u.y - y) ^ 2 + (u.z + 2 - z) ^ 2)
        if d < Config.BLAST_R then
            u.hp = math.max(0, u.hp - (d < 2 and 2 or 1))
            u.flash = 1.2
            snd.hit:playNote(98, 0.4, 0.2)
            Harness.count("hits")
        end
    end
end

local function updateParts(dt)
    for i = #Game.parts, 1, -1 do
        local q = Game.parts[i]
        q.t = q.t - dt
        q.vz = q.vz - Config.GRAVITY * dt
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        q.z = q.z + q.vz * dt
        local g = Vox.heightAt(math.floor(q.x), math.floor(q.y))
        if q.z < g then
            q.z = g
            q.vz = -q.vz * 0.4
            q.vx, q.vy = q.vx * 0.6, q.vy * 0.6
        end
        if q.t <= 0 then table.remove(Game.parts, i) end
    end
end

local function enterAim()
    setPhase("aim", 0)
    aiPending = nil
    Game.you.charging = false
    -- the foe always self-aims; in smoke builds the player does too
    if State.turn == "foe" or Harness.enabled then
        local you = State.turn == "you"
        local u = you and Game.you or Game.foe
        local tgt = you and Game.foe or Game.you
        local err = you and Config.AP_ERR or State.aiErr
        u.az, u.power = Game.solveAim(u, tgt, err)
        aiPending = { u = u, t = Config.AI_THINK_T }
        if not you then
            State.aiErr = math.max(Config.AI_ERR_MIN, State.aiErr * Config.AI_DECAY)
        end
    end
end

local function endResolve()
    if Game.you.hp <= 0 or Game.foe.hp <= 0 then
        local youWon = Game.foe.hp <= 0 -- mutual kill goes to the shooter's favor
        if youWon then
            State.youWins = State.youWins + 1
            Harness.count("roundwins")
        else
            State.foeWins = State.foeWins + 1
        end
        Harness.count("rounds")
        if State.youWins >= Config.ROUNDS or State.foeWins >= Config.ROUNDS then
            State.youWon = State.youWins >= Config.ROUNDS
            State.mode = "over"
            State.phaseT = 1.2
            Harness.count("matches")
            if State.youWon then Harness.count("matchwins") end
        else
            Game.startRound()
        end
    else
        State.turn = State.turn == "you" and "foe" or "you"
        rollWind()
        snd.turn:playNote(523, 0.2, 0.06)
        setPhase("banner", Config.BANNER_T,
            State.turn == "you" and "YOUR TURN" or "FOE'S TURN")
    end
end

function Game.update(dt)
    local inp = Input.state
    if State.mode == "title" then
        if inp.confirm then Game.startMatch() end
        return
    end
    if State.mode == "over" then
        State.phaseT = math.max(0, State.phaseT - dt)
        updateParts(dt)
        if State.phaseT <= 0 and inp.confirm then Game.startMatch() end
        return
    end
    physZ(Game.you, dt)
    physZ(Game.foe, dt)
    Game.you.flash = math.max(0, Game.you.flash - dt)
    Game.foe.flash = math.max(0, Game.foe.flash - dt)
    updateParts(dt)
    local ph = State.phase
    if ph == "banner" then
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then enterAim() end
    elseif ph == "aim" then
        if aiPending then
            aiPending.t = aiPending.t - dt
            if aiPending.t <= 0 then
                local u = aiPending.u
                aiPending = nil
                Game.fire(u)
            end
        else
            local u = Game.you
            if inp.aim then u.az = inp.aim end
            if inp.rotL then u.az = u.az - Config.ROT_SPEED * dt end
            if inp.rotR then u.az = u.az + Config.ROT_SPEED * dt end
            if inp.chargeStart then
                u.charging, u.meterT = true, 0
            end
            if u.charging then
                -- power meter ping-pongs 0 -> 1 -> 0 while A is held
                u.meterT = u.meterT + dt
                local ph = (u.meterT / Config.POWER_CADENCE) % 2
                u.power = ph <= 1 and ph or 2 - ph
                if inp.fire then
                    u.charging = false
                    Game.fire(u)
                end
            end
        end
    elseif ph == "flight" then
        local s = Game.shot
        for _ = 1, 4 do
            if stepProj(s, dt / 4) then
                explode(s.x, s.y, s.z)
                Game.shot = nil
                setPhase("resolve", Config.RESOLVE_T)
                break
            end
        end
        if Game.shot then
            s.t = s.t - dt
            if s.t <= 0 then
                Game.shot = nil
                setPhase("resolve", Config.RESOLVE_T)
            elseif math.random() < 0.4 and #Game.parts <= 40 then
                -- faint smoke trail
                Game.parts[#Game.parts + 1] =
                    { x = s.x, y = s.y, z = s.z, vx = 0, vy = 0, vz = 0, t = 0.2, m = 3 }
            end
        end
    elseif ph == "resolve" then
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then endResolve() end
    end
end
