-- Crumble: a field of plateaus and columns, slime rising from the floor.
-- Columns crumble underfoot; gems spawn on high ground; the crank winds a
-- spring jump. Exercises terrain ADDITION (Vox.set + Vox.repaint) where
-- Rubble only carved.

local SLIME = 1 -- material reserved for slime (terrain uses 2/3 only)

-- urgent pulse: driving E-minor eighths under sparse stabs
local TRACK = {
    bpm = 138,
    bass = { 40, 0, 40, 0, 40, 0, 43, 0, 40, 0, 40, 0, 38, 0, 43, 0 },
    lead = { 64, 0, 0, 0, 0, 0, 64, 0, 67, 0, 0, 0, 64, 0, 62, 0 },
    hat  = { 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1 },
}

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

-- Kit.spawnPart with Crumble's original debris tunables
local popts = { speed = 12, vzMin = 3, vzMax = 12 }
local function spawnPart(x, y, z, m)
    popts.m = m
    Kit.spawnPart(Game.parts, x, y, z, popts)
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
                Vox.column(x, y, h, 2)
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
                Vox.column(x, y, h, 2)
            end
        end
    end
    -- guaranteed spawn plateau at center
    for x = Vox.W // 2 - 3, Vox.W // 2 + 3 do
        for y = Vox.D // 2 - 3, Vox.D // 2 + 3 do
            Vox.column(x, y, 2, 2)
        end
    end
    Vox.buildBG()
end

function Game.spawnGem()
    if Kit.mode ~= "play" or #Game.gems >= Config.GEMS then return end
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
    Kit.setMode("play")
    Music.set(TRACK)
    for _ = 1, Config.GEMS do Game.spawnGem() end
end

function Game.init()
    Kit.loadBest()
    Game.startRun()
    Kit.setMode("title")
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
    Kit.shake(0.4)
    Snd.play("noise", 65, 0.4, 0.5)
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
    Snd.play("saw", 98, 0.2, 0.4)
    Harness.count("hurt")
    if State.hp <= 0 then
        Kit.setMode("dead", 1)
        State.newBest = Kit.saveBest(State.score)
        Music.stop()
        for _ = 1, 12 do spawnPart(p.x, p.y, p.z + 1, math.random(2, 4)) end
        Harness.count("gameovers")
    end
end

-- the footprint cell actually holding the player up: the argmax column of
-- VoxPhys.groundAt's stride-1 footprint sample (same iteration order, first
-- max wins). Crumbling and slime contact key off THIS column — keying off
-- the center let players camp a column center after one voxel crumbled,
-- and hurt rim-standers via slime under an overhang they never touched.
local function supportCell(x, y, hw)
    local floor = math.floor
    local bx, by, g = floor(x), floor(y), -1
    for cy = floor(y - hw), floor(y + hw) do
        for cx = floor(x - hw), floor(x + hw) do
            local h = Vox.heightAt(cx, cy)
            if h > g then g, bx, by = h, cx, cy end
        end
    end
    return bx, by, g
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
            Snd.play("square", 220 + p.charge * 660, 0.12, 0.3)
            if p.charge > 0.2 then Harness.count("springs") end
            p.charge = 0
        end
    end
    physZ(p, dt)
    if p.grounded then
        local sx, sy, g = supportCell(p.x, p.y, p.hw)
        local topz = g - 1
        if topz >= 1 then
            if Vox.get(sx, sy, topz) == SLIME then
                p.crumbleT = Config.CRUMBLE_T
                if p.inv <= 0 then hurtPlayer() end
            else
                -- the column you stand on crumbles away
                p.crumbleT = p.crumbleT - dt
                if p.crumbleT <= 0 then
                    p.crumbleT = Config.CRUMBLE_T
                    Vox.set(sx, sy, topz, nil)
                    Vox.repaint(sx - 1, sx + 1)
                    Snd.play("noise", 160, 0.08, 0.3)
                    spawnPart(sx, sy, topz, 2)
                    Harness.count("crumbled")
                end
            end
        else
            p.crumbleT = Config.CRUMBLE_T
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
            Snd.play("square", 1047, 0.06, 0.3)
            Util.after(0.06, function() Snd.play("square", 1568, 0.09, 0.3) end)
            for _ = 1, 5 do spawnPart(gm.x, gm.y, gm.z + 1, 4) end
            Harness.count("gems")
            Util.after(0.8, Game.spawnGem)
        end
    end
end

-- slime surface bubbles
local function bubbles()
    if State.slimeLevel < 1 or math.random() > 0.15 then return end
    local x = math.random(1, Vox.W - 2)
    local y = math.random(1, Vox.D - 2)
    local h, m = Vox.surfaceAt(x, y)
    if m == SLIME and h == State.slimeLevel + 1 then
        spawnPart(x, y, State.slimeLevel + 1, 1)
    end
end

function Game.update(dt)
    Music.update(dt)
    Kit.updateShake(dt)
    local inp = Input.state
    if Kit.mode == "title" then
        if inp.confirm then Game.startRun() end
        return
    end
    if Kit.mode == "dead" then
        Kit.updateParts(Game.parts, dt)
        if Kit.modeT <= 0 and inp.confirm then Game.startRun() end
        return
    end
    State.t = State.t + dt
    State.riseIn = State.riseIn - dt
    if State.riseIn <= 0 then
        State.riseInterval = math.max(Config.SLIME_MIN, State.riseInterval * Config.SLIME_DECAY)
        State.riseIn = State.riseInterval
        riseSlime()
    end
    updatePlayer(dt, inp)
    updateGems(dt)
    Kit.updateParts(Game.parts, dt)
    bubbles()
end
