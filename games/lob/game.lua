-- Lob: turn-based artillery. Two mortars on a hilly heightfield with a
-- central ridge; shells fly a 45-degree parabola bent by per-turn wind
-- and carve craters. The foe's aim solver brackets tighter every shot.

Game = {
    you = nil,
    foe = nil,
    shot = nil,
    parts = {},
}

-- lazy pastoral loop: soft C-G bass ambling under sparse major-scale tones
local TRACK = {
    bpm = 72,
    bass = { 36, 0, 0, 0, 43, 0, 0, 0, 41, 0, 0, 0, 43, 0, 0, 0 },
    lead = { 0, 0, 72, 0, 0, 0, 76, 0, 0, 0, 79, 0, 76, 0, 0, 0 },
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
    local bumps = { base = 1.5 }
    -- rolling hills
    for _ = 1, 10 do
        bumps[#bumps + 1] = { math.random(6, W - 7), math.random(5, D - 6),
            math.random(6, 14), math.random(1, 4) + math.random() }
    end
    -- central ridge blocks the flat shot and forces real lobs
    for _ = 1, 4 do
        bumps[#bumps + 1] = { W // 2 + math.random(-6, 6), math.random(8, D - 9),
            math.random(5, 9), math.random(3, 6) }
    end
    local hm = Vox.bumpField(W, D, bumps)
    -- flat firing pads
    for _, p in ipairs({ { 12, D // 2 }, { W - 13, D // 2 } }) do
        for x = p[1] - 4, p[1] + 4 do
            for y = p[2] - 4, p[2] + 4 do
                hm[y + 1][x + 1] = 2
            end
        end
    end
    -- defaults are lob's exact rules: mat 2, bright caps only from height 6
    Vox.fromHeightmap(hm)
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
    Kit.setMode("play")
    Music.set(TRACK)
    Game.startRound()
end

function Game.init()
    Kit.loadBest()
    Game.startMatch()
    Kit.setMode("title")
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

-- shared solver opts; err and wind are per-shot (the foe's err shrinks
-- every shot: classic bracketing). Muzzle matches launch() above.
local solveOpts = {
    vmin = Config.VMIN, vmax = Config.VMAX,
    elevCos = Config.ELEV_COS, elevSin = Config.ELEV_SIN,
    muzzle = function(o, az)
        return o.x + math.cos(az) * 2, o.y + math.sin(az) * 2, o.z + 4.5
    end,
}

function Game.fire(u)
    Game.shot = launch(u)
    Snd.play("tri", 131, 0.15, 0.4)
    Harness.count("shots")
    setPhase("flight", 0)
end

local function explode(x, y, z)
    local removed = Vox.carve(x, y, z, Config.CARVE_R)
    Harness.count("carved", #removed)
    Snd.play("noise", 80, 0.3, 0.5)
    Kit.burst(Game.parts, removed, 10)
    Kit.spawnPart(Game.parts, x, y, z, { m = 4, count = 6, speed = 14, vzMax = 14 })
    for _, u in ipairs({ Game.you, Game.foe }) do
        local d = math.sqrt((u.x - x) ^ 2 + (u.y - y) ^ 2 + (u.z + 2 - z) ^ 2)
        if d < Config.BLAST_R then
            u.hp = math.max(0, u.hp - (d < 2 and 2 or 1))
            u.flash = 1.2
            Snd.play("saw", 98, 0.2, 0.4)
            Harness.count("hits")
        end
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
        solveOpts.err = you and Config.AP_ERR or State.aiErr
        solveOpts.wind = State.wind
        local az, v = VoxProj.solve(u, tgt, solveOpts)
        u.az = az
        u.power = (v - Config.VMIN) / (Config.VMAX - Config.VMIN)
        aiPending = { u = u, t = Config.AI_THINK_T }
        if not you then
            State.aiErr = math.max(Config.AI_ERR_MIN, State.aiErr * Config.AI_DECAY)
        end
    end
end

local function endResolve()
    if Game.you.hp <= 0 or Game.foe.hp <= 0 then
        local youWon = Game.foe.hp <= 0 -- mutual kill goes to the player
        if youWon then
            State.youWins = State.youWins + 1
            Harness.count("roundwins")
        else
            State.foeWins = State.foeWins + 1
        end
        Harness.count("rounds")
        if State.youWins >= Config.ROUNDS or State.foeWins >= Config.ROUNDS then
            State.youWon = State.youWins >= Config.ROUNDS
            State.newBest = Kit.saveBest(State.youWins)
            Kit.setMode("over", 1.2)
            Music.stop()
            Harness.count("matches")
            if State.youWon then Harness.count("matchwins") end
        else
            Game.startRound()
        end
    else
        State.turn = State.turn == "you" and "foe" or "you"
        rollWind()
        Snd.play("square", 523, 0.06, 0.2)
        setPhase("banner", Config.BANNER_T,
            State.turn == "you" and "YOUR TURN" or "FOE'S TURN")
    end
end

function Game.update(dt)
    Music.update(dt)
    local inp = Input.state
    if Kit.mode == "title" then
        if inp.confirm then Game.startMatch() end
        return
    end
    if Kit.mode == "over" then
        Kit.updateParts(Game.parts, dt)
        if Kit.modeT <= 0 and inp.confirm then Game.startMatch() end
        return
    end
    physZ(Game.you, dt)
    physZ(Game.foe, dt)
    Game.you.flash = math.max(0, Game.you.flash - dt)
    Game.foe.flash = math.max(0, Game.foe.flash - dt)
    Kit.updateParts(Game.parts, dt)
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
        if stepProj(s, dt) then
            explode(s.x, s.y, s.z)
            Game.shot = nil
            setPhase("resolve", Config.RESOLVE_T)
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
