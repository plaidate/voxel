-- Crumble: a field of plateaus and columns, slime rising from the floor.
-- Columns crumble underfoot; gems spawn on high ground; the crank winds a
-- spring jump. Exercises terrain ADDITION (Vox.set + Vox.repaint) where
-- Rubble only carved.

local snd = {
    gem = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    spring = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    crack = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    rise = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    hurt = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
}

local SLIME = 1 -- material reserved for slime (terrain uses 2/3 only)

Game = {
    player = nil,
    gems = {},
    parts = {},
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

local tryMove = VoxPhys.tryMove

local function physZ(e, dt)
    VoxPhys.physZ(e, dt, Config.GRAVITY)
end

function Game.buildWorld()
    Vox.clear()
    -- bedrock floor (uniform: material 1 is reserved for slime)
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            Vox.set(x, y, 0, 2)
        end
    end
    -- broad plateaus
    for _ = 1, 12 do
        local w, d = math.random(6, 14), math.random(5, 11)
        local px = math.random(2, Vox.W - 2 - w)
        local py = math.random(2, Vox.D - 2 - d)
        local h = math.random(2, 5)
        for x = px, px + w - 1 do
            for y = py, py + d - 1 do
                for z = 1, h do Vox.set(x, y, z, z == h and 3 or 2) end
            end
        end
    end
    -- tall columns
    for _ = 1, 14 do
        local cx = math.random(4, Vox.W - 7)
        local cy = math.random(4, Vox.D - 7)
        local h = math.random(5, 9)
        for x = cx, cx + 2 do
            for y = cy, cy + 2 do
                for z = 1, h do Vox.set(x, y, z, z == h and 3 or 2) end
            end
        end
    end
    -- guaranteed spawn plateau at center
    for x = Vox.W // 2 - 3, Vox.W // 2 + 3 do
        for y = Vox.D // 2 - 3, Vox.D // 2 + 3 do
            for z = 1, 2 do Vox.set(x, y, z, z == 2 and 3 or 2) end
        end
    end
    Vox.buildBG()
end

function Game.spawnPart(x, y, z, m)
    if #Game.parts > 40 then return end
    Game.parts[#Game.parts + 1] = {
        x = x, y = y, z = z,
        vx = (math.random() - 0.5) * 12,
        vy = (math.random() - 0.5) * 12,
        vz = math.random() * 9 + 3,
        t = 0.6 + math.random() * 0.4,
        m = m,
    }
end

function Game.spawnGem()
    if State.mode ~= "play" or #Game.gems >= Config.GEMS then return end
    local bestX, bestY, bestG = nil, nil, -1
    for _ = 1, 60 do
        local x = math.random(3, Vox.W - 4)
        local y = math.random(3, Vox.D - 4)
        local g = Vox.heightAt(x, y)
        if g >= State.slimeLevel + 3 and g < Vox.H - 1 then
            Game.gems[#Game.gems + 1] = { x = x + 0.5, y = y + 0.5, z = g, phase = math.random() * 6 }
            return
        end
        if g > bestG and g > State.slimeLevel + 1 then
            bestX, bestY, bestG = x, y, g
        end
    end
    if bestX then
        Game.gems[#Game.gems + 1] = { x = bestX + 0.5, y = bestY + 0.5, z = bestG, phase = 0 }
    end
end

function Game.startRun()
    State.reset()
    Game.buildWorld()
    Util.clearPending()
    Game.player = {
        x = Vox.W / 2, y = Vox.D / 2, z = 3, vz = 0,
        hw = 1.1, grounded = true, inv = 0,
        charge = 0, crumbleT = Config.CRUMBLE_T,
    }
    Game.gems = {}
    Game.parts = {}
    State.mode = "play"
    for _ = 1, Config.GEMS do Game.spawnGem() end
end

function Game.init()
    Game.startRun()
    State.mode = "title"
end

local function riseSlime()
    State.slimeLevel = State.slimeLevel + 1
    local L = math.min(State.slimeLevel, Vox.H - 2)
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            for z = 1, L do
                if not Vox.get(x, y, z) then Vox.set(x, y, z, SLIME) end
            end
        end
    end
    Vox.repaint(0, Vox.W - 1)
    State.shake = 0.4
    snd.rise:playNote(65, 0.5, 0.4)
    Harness.set("slime", State.slimeLevel)
    -- relocate buried gems
    for i = #Game.gems, 1, -1 do
        local gm = Game.gems[i]
        if Vox.heightAt(math.floor(gm.x), math.floor(gm.y)) ~= gm.z then
            table.remove(Game.gems, i)
            Util.after(0.5, Game.spawnGem)
        end
    end
end

local function hurtPlayer()
    local p = Game.player
    p.inv = Config.IFRAMES
    p.vz = 11 -- pop up off the slime for an escape chance
    p.grounded = false
    State.hp = State.hp - 1
    snd.hurt:playNote(98, 0.4, 0.2)
    Harness.count("hurt")
    if State.hp <= 0 then
        State.mode = "dead"
        State.t = 0
        for _ = 1, 12 do Game.spawnPart(p.x, p.y, p.z + 1, math.random(2, 4)) end
        Harness.count("gameovers")
    end
end

local function updatePlayer(dt, inp)
    local p = Game.player
    p.inv = math.max(0, p.inv - dt)
    p.charge = math.min(1, p.charge + (inp.charge or 0))
    local dx, dy = inp.mx, inp.my
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.7071, dy * 0.7071 end
    tryMove(p, p.x + dx * Config.MOVE_SPEED * dt, p.y)
    tryMove(p, p.x, p.y + dy * Config.MOVE_SPEED * dt)
    if p.grounded and (inp.jump or inp.spring) then
        local boost = inp.spring and p.charge * Config.SPRING_MAX or 0
        p.vz = Config.JUMP_VEL + boost
        p.grounded = false
        if inp.spring then
            snd.spring:playNote(220 + p.charge * 660, 0.3, 0.12)
            if p.charge > 0.2 then Harness.count("springs") end
            p.charge = 0
        end
    end
    physZ(p, dt)
    local fx, fy = math.floor(p.x), math.floor(p.y)
    local topz = math.floor(p.z + 0.5) - 1
    if p.grounded and topz >= 1 then
        local under = Vox.get(fx, fy, topz)
        if under == SLIME then
            p.crumbleT = Config.CRUMBLE_T
            if p.inv <= 0 then hurtPlayer() end
        elseif under then
            -- the column you stand on crumbles away
            p.crumbleT = p.crumbleT - dt
            if p.crumbleT <= 0 then
                p.crumbleT = Config.CRUMBLE_T
                Vox.set(fx, fy, topz, nil)
                Vox.repaint(fx - 1, fx + 1)
                snd.crack:playNote(160, 0.3, 0.08)
                Game.spawnPart(fx, fy, topz, 2)
                Harness.count("crumbled")
            end
        end
    else
        p.crumbleT = Config.CRUMBLE_T
    end
end

local function updateGems(dt)
    local p = Game.player
    for i = #Game.gems, 1, -1 do
        local gm = Game.gems[i]
        gm.phase = gm.phase + dt
        local dx, dy = gm.x - p.x, gm.y - p.y
        if dx * dx + dy * dy < 4 and math.abs(gm.z - p.z) < 3 then
            table.remove(Game.gems, i)
            State.score = State.score + Config.GEM_SCORE
            snd.gem:playNote(1047, 0.3, 0.06)
            Util.after(0.06, function() snd.gem:playNote(1568, 0.3, 0.09) end)
            for _ = 1, 5 do Game.spawnPart(gm.x, gm.y, gm.z + 1, 4) end
            Harness.count("gems")
            Util.after(0.8, Game.spawnGem)
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

-- slime surface bubbles
local function bubbles()
    if State.slimeLevel < 1 or math.random() > 0.15 then return end
    local x = math.random(1, Vox.W - 2)
    local y = math.random(1, Vox.D - 2)
    if Vox.get(x, y, State.slimeLevel) == SLIME
        and Vox.heightAt(x, y) == State.slimeLevel + 1 then
        Game.spawnPart(x, y, State.slimeLevel + 1, 1)
    end
end

function Game.update(dt)
    local inp = Input.state
    if State.mode == "title" then
        if inp.confirm then Game.startRun() end
        return
    end
    if State.mode == "dead" then
        State.t = State.t + dt
        updateParts(dt)
        if State.t > 1 and inp.confirm then Game.startRun() end
        return
    end
    State.t = State.t + dt
    State.shake = math.max(0, State.shake - dt)
    State.riseIn = State.riseIn - dt
    if State.riseIn <= 0 then
        State.riseInterval = math.max(Config.SLIME_MIN, State.riseInterval * Config.SLIME_DECAY)
        State.riseIn = State.riseInterval
        riseSlime()
    end
    updatePlayer(dt, inp)
    updateGems(dt)
    updateParts(dt)
    bubbles()
end
