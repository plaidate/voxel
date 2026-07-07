-- Summit: sumo on a four-terrace ziggurat above a goo sea. Terrace steps
-- are two voxels, so only you (with B-jump) can climb — brutes have to be
-- knocked down. A shoves; a full crank-wound meter turns the next A into
-- a radial spin. The lowest terrace erodes into the goo on a timer.

local snd = {
    shove = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    spin = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
    splash = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    rumble = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    round = playdate.sound.synth.new(playdate.sound.kWaveTriangle),
}

local GOO = 1
local TEMPLATE = { { 27, 23 }, { 20, 17 }, { 13, 11 }, { 7, 6 } }

Game = {
    player = nil,
    brutes = {},
    parts = {},
    terr = {},
    low = 1,
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

Game.bruteModel = VoxModel.fromLayers({
    { "1.1", "1.1" },
    { "111", "111" },
    { "111", "111" },
    { ".4.", ".4." },
})

local CX, CY = 48, 32

function Game.buildZiggurat()
    Vox.clear()
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            Vox.set(x, y, 0, 2)
            local level = 0
            for i = 4, 1, -1 do
                local t = Game.terr[i]
                if t and math.abs(x - CX) <= t[1] and math.abs(y - CY) <= t[2] then
                    level = i
                    break
                end
            end
            if level > 0 then
                local top = 1 + 2 * level
                local cap = (level % 2 == 0) and 2 or 3
                for z = 1, top do
                    Vox.set(x, y, z, z == top and cap or 2)
                end
            else
                Vox.set(x, y, 1, GOO)
            end
        end
    end
    Vox.buildBG()
end

local function gooAt(x, y)
    return Vox.get(math.floor(x), math.floor(y),
        Vox.heightAt(math.floor(x), math.floor(y)) - 1) == GOO
end

local function spawnRound()
    Game.terr = {}
    for i, t in ipairs(TEMPLATE) do Game.terr[i] = { t[1], t[2] } end
    Game.low = 1
    Game.buildZiggurat()
    Game.parts = {}
    Game.player = {
        x = CX + 0.5, y = CY + 0.5, z = 9, vz = 0, hw = 1.1, grounded = true,
        fx = 1, fy = 0, cd = 0, charge = 0, kbx = 0, kby = 0,
        model = Game.playerModel,
    }
    Game.brutes = {}
    local n = math.min(Config.BRUTES_BASE + State.round, 6)
    for i = 1, n do
        local a = (i - 0.5) / n * math.pi * 2
        local lvl = 1 + (i % 3)
        local t = Game.terr[lvl]
        local bx = CX + math.cos(a) * (t[1] - 3)
        local by = CY + math.sin(a) * (t[2] - 3)
        Game.brutes[#Game.brutes + 1] = {
            x = bx, y = by, z = 1 + 2 * lvl, vz = 0, hw = 1.1, grounded = true,
            cd = 1 + math.random(), kbx = 0, kby = 0, model = Game.bruteModel,
        }
    end
    State.erodeIn = Config.EROSION_T
    State.phase = "banner"
    State.phaseT = Config.BANNER_T
    State.banner = "ROUND " .. State.round
end

function Game.startGame()
    State.reset()
    State.mode = "play"
    spawnRound()
end

function Game.init()
    Game.startGame()
    State.mode = "title"
end

local function erode()
    local t = Game.terr[Game.low]
    if not t then return end
    t[1], t[2] = t[1] - 2, t[2] - 2
    local nxt = Game.terr[Game.low + 1]
    if t[1] < 3 or (nxt and t[1] <= nxt[1]) then
        Game.terr[Game.low] = false
        Game.low = Game.low + 1
    end
    Game.buildZiggurat()
    snd.rumble:playNote(50, 0.5, 0.4)
    Harness.count("erosions")
end

-- move with knockback; walking (small kb) refuses goo, being thrown
-- doesn't
local function moveActor(e, mx, my, speed, dt)
    local vx = mx * speed + e.kbx
    local vy = my * speed + e.kby
    e.kbx, e.kby = e.kbx * 0.88, e.kby * 0.88
    local flying = math.abs(e.kbx) + math.abs(e.kby) > 4
    local nx, ny = e.x + vx * dt, e.y + vy * dt
    if flying or not gooAt(nx, e.y) then
        VoxPhys.tryMove(e, nx, e.y)
    end
    if flying or not gooAt(e.x, ny) then
        VoxPhys.tryMove(e, e.x, ny)
    end
    VoxPhys.physZ(e, dt, Config.GRAVITY)
end

local function splashKO(e)
    for _ = 1, 7 do Kit.spawnPart(Game.parts, e.x, e.y, e.z + 1, 1) end
    snd.splash:playNote(65, 0.5, 0.3)
end

local function shoveBrutes(px, py, fx, fy, radius, kb, arc)
    local hits = 0
    for _, b in ipairs(Game.brutes) do
        local dx, dy = b.x - px, b.y - py
        local d = math.sqrt(dx * dx + dy * dy)
        if d < radius and d > 0.01
            and (not arc or dx * fx + dy * fy > 0) then
            b.kbx = b.kbx + dx / d * kb
            b.kby = b.kby + dy / d * kb
            b.vz = 4
            b.grounded = false
            hits = hits + 1
        end
    end
    return hits
end

local apJumpCd = 0
local function autoplay(dt, inp)
    local p = Game.player
    inp.charge = 0.02
    apJumpCd = math.max(0, apJumpCd - dt)
    local best, bd
    for _, b in ipairs(Game.brutes) do
        local d = (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2
        if not bd or d < bd then bd, best = d, b end
    end
    if not best then return end
    local dx, dy = best.x - p.x, best.y - p.y
    inp.mx = (dx > 1 and 1) or (dx < -1 and -1) or 0
    inp.my = (dy > 1 and 1) or (dy < -1 and -1) or 0
    if bd < Config.SHOVE_R * Config.SHOVE_R * 0.8 then inp.act = true end
    -- crowd control: spin when surrounded and ready
    if p.charge >= 1 then
        local near = 0
        for _, b in ipairs(Game.brutes) do
            if (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2 < 25 then near = near + 1 end
        end
        if near >= 2 then inp.act = true end
    end
    if best.z > p.z + 1 and apJumpCd <= 0 then
        inp.jump = true
        apJumpCd = 0.6
    end
end

function Game.update(dt)
    local inp = Input.state
    if State.mode == "title" then
        if inp.confirm then Game.startGame() end
        return
    end
    if State.mode == "over" then
        State.phaseT = math.max(0, State.phaseT - dt)
        Kit.updateParts(Game.parts, dt)
        if State.phaseT <= 0 and inp.confirm then Game.startGame() end
        return
    end
    Kit.updateParts(Game.parts, dt)
    if State.phase == "banner" then
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then State.phase = "run" end
        return
    end
    if Harness.enabled then autoplay(dt, inp) end
    local p = Game.player
    p.cd = math.max(0, p.cd - dt)
    p.charge = math.min(1, p.charge + (inp.charge or 0))
    if inp.mx ~= 0 or inp.my ~= 0 then p.fx, p.fy = inp.mx, inp.my end
    if inp.jump and p.grounded then
        p.vz = Config.JUMP_VEL
        p.grounded = false
    end
    moveActor(p, inp.mx, inp.my, Config.SPEED, dt)
    if inp.act and p.cd <= 0 then
        p.cd = Config.SHOVE_CD
        if p.charge >= 1 then
            p.charge = 0
            snd.spin:playNote(150, 0.5, 0.25)
            shoveBrutes(p.x, p.y, 0, 0, Config.SPIN_R, Config.SPIN_KB, false)
            Harness.count("spins")
        else
            snd.shove:playNote(330, 0.3, 0.07)
            shoveBrutes(p.x, p.y, p.fx, p.fy, Config.SHOVE_R, Config.SHOVE_KB, true)
            Harness.count("shoves")
        end
    end
    if p.grounded and gooAt(p.x, p.y) then
        splashKO(p)
        State.mode = "over"
        State.reason = "IN THE GOO"
        State.phaseT = 1.2
        Harness.count("gameovers")
        return
    end
    local sp = Config.BRUTE_SPEED + State.round * Config.BRUTE_SPEED_RND
    for i = #Game.brutes, 1, -1 do
        local b = Game.brutes[i]
        b.cd = math.max(0, b.cd - dt)
        local dx, dy = p.x - b.x, p.y - b.y
        local d = math.sqrt(dx * dx + dy * dy)
        local mx = (dx > 0.5 and 1) or (dx < -0.5 and -1) or 0
        local my = (dy > 0.5 and 1) or (dy < -0.5 and -1) or 0
        moveActor(b, mx, my, sp, dt)
        if d > 0.01 and d < 2.6 and b.cd <= 0 and math.abs(b.z - p.z) < 2 then
            b.cd = Config.BRUTE_CD
            p.kbx = p.kbx + dx / d * Config.BRUTE_KB
            p.kby = p.kby + dy / d * Config.BRUTE_KB
            p.vz = 4
            p.grounded = false
            snd.shove:playNote(196, 0.3, 0.07)
        end
        if b.grounded and gooAt(b.x, b.y) then
            splashKO(b)
            table.remove(Game.brutes, i)
            State.score = State.score + 10
            Harness.count("kos")
        end
    end
    if #Game.brutes == 0 then
        State.score = State.score + 25
        State.round = State.round + 1
        snd.round:playNote(784, 0.3, 0.12)
        Harness.count("rounds")
        spawnRound()
        return
    end
    State.erodeIn = State.erodeIn - dt
    if State.erodeIn <= 0 then
        State.erodeIn = Config.EROSION_T
        erode()
    end
end
