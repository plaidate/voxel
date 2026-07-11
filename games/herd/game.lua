-- Herd: pocket Lemmings. Sheep pour from the west platform and march
-- east to the gate; ridges block them, goo pools scare them into
-- detours, long falls splat them. Your only tools remove terrain: dig
-- notches, blast gaps, even drain goo by carving off its surface. Crank
-- sets the release rate.

local GOO = 1 -- surface material sheep refuse to walk on (and die in)

-- bucolic waltz-ish: F/C oom-pah-pah lilt, no hat
local TRACK = {
    bpm = 100,
    bass = { 41, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0 },
    lead = { 0, 0, 0, 65, 0, 0, 69, 0, 0, 0, 0, 64, 0, 0, 67, 0 },
}

Game = {
    crits = {},
    parts = {},
}

Game.sheepModel = VoxModel.fromLayers({
    { "44", "44", "44" },
    { "..", "..", "11" },
})

local tryMove = VoxPhys.tryMove

-- top-of-column material (integer coords)
local function surfMat(x, y)
    local _, m = Vox.surfaceAt(x, y)
    return m
end

-- Kit.spawnPart with Herd's original debris tunables
local popts = { speed = 12, vzMin = 3, vzMax = 12 }
local function spawnPart(x, y, z, m)
    popts.m = m
    Kit.spawnPart(Game.parts, x, y, z, popts)
end

function Game.genLevel(level)
    Vox.clear()
    -- bedrock + 3 courses of soil; light grid etched on top
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            Vox.set(x, y, 0, 2)
            Vox.set(x, y, 1, 2)
            Vox.set(x, y, 2, 2)
        end
    end
    Vox.floorGrid(2, 3, 8, 3)
    -- spawn platform, west
    for x = 3, 9 do
        for y = Vox.D // 2 - 5, Vox.D // 2 + 5 do
            Vox.set(x, y, 4, 2)
            Vox.set(x, y, 5, 3)
        end
    end
    -- ridges: level 1 has a gap to stream through, later ones don't
    local ridgeXs = {}
    local n = math.min(1 + level // 2, 3)
    local bases = { 30, 52, 72 }
    for i = 1, n do
        local rx = bases[i] + math.random(-4, 4)
        ridgeXs[#ridgeXs + 1] = rx
        local gapY = (level == 1) and math.random(8, Vox.D - 16) or -99
        for x = rx, rx + 1 do
            for y = 0, Vox.D - 1 do
                if y < gapY or y > gapY + 6 then
                    for z = 4, 7 do Vox.set(x, y, z, z == 7 and 3 or 2) end
                end
            end
        end
    end
    -- goo pools (never against a ridge, the platform or the gate)
    for _ = 1, 2 + level do
        for _ = 1, 20 do
            local px = math.random(16, 82)
            local py = math.random(6, Vox.D - 7)
            local ok = true
            for _, rx in ipairs(ridgeXs) do
                if math.abs(px - rx) < 7 then ok = false end
            end
            if ok then
                local r = math.random(2, 4)
                for x = px - r, px + r do
                    for y = py - r, py + r do
                        if (x - px) ^ 2 + (y - py) ^ 2 <= r * r
                            and x > 12 and x < 86 and y > 2 and y < Vox.D - 3 then
                            Vox.set(x, y, 3, GOO)
                        end
                    end
                end
                break
            end
        end
    end
    -- the gate: decorative posts past the save line
    for y = 4, Vox.D - 5, 6 do
        for z = 4, 6 do Vox.set(91, y, z, 4) end
    end
    Vox.buildBG()
end

local function beginLevel()
    Game.genLevel(State.level)
    Game.crits = {}
    Game.parts = {}
    State.timer = Config.LEVEL_T
    State.saved, State.dead, State.spawned = 0, 0, 0
    State.quota = Config.QUOTA_BASE + math.min(State.level - 1, 3)
    State.blasts = Config.BLASTS
    State.spawnT = 1
    Kit.setMode("play", Config.BANNER_T)
    State.banner = "LEVEL " .. State.level .. " - SAVE " .. State.quota
end

function Game.startGame()
    State.reset()
    Music.set(TRACK)
    beginLevel()
end

function Game.init()
    Kit.loadBest()
    Game.startGame()
    Kit.setMode("title")
end

local function spawnSheep()
    State.spawned = State.spawned + 1
    local y = Vox.D // 2 + math.random(-4, 4)
    Game.crits[#Game.crits + 1] = {
        x = 6, y = y + 0.5, z = Vox.heightAt(6, y), vz = 0,
        hw = 0.8, grounded = true,
        side = math.random() < 0.5 and 1 or -1, bestX = 6, noProgT = 0,
    }
    Snd.play("square", 880, 0.05, 0.25)
    Harness.count("spawned")
end

local function killSheep(i, why)
    local c = table.remove(Game.crits, i)
    State.dead = State.dead + 1
    for _ = 1, 5 do spawnPart(c.x, c.y, c.z + 1, why == "goo" and 1 or 4) end
    Snd.play("saw", why == "goo" and 65 or 110, 0.15, 0.4)
    Harness.count("deaths")
end

-- goo ahead reads as a wall to a sheep
local function walkable(c, nx, ny)
    if surfMat(math.floor(nx), math.floor(ny)) == GOO then return false end
    return tryMove(c, nx, ny)
end

local function updateSheep(dt)
    local step = Config.SPEED * dt
    for i = #Game.crits, 1, -1 do
        local c = Game.crits[i]
        local moved = walkable(c, c.x + step, c.y)
        if not moved then
            if walkable(c, c.x, c.y + c.side * step) then
                moved = true
            elseif walkable(c, c.x, c.y - c.side * step) then
                c.side = -c.side
                moved = true
            else
                tryMove(c, c.x - step, c.y) -- boxed in: shuffle back
            end
        end
        -- "stuck" = no eastward progress, even while sliding along a wall
        if c.x > c.bestX then
            c.bestX = c.x
            c.noProgT = 0
        else
            c.noProgT = c.noProgT + dt
        end
        local fallV = c.vz
        VoxPhys.physZ(c, dt, Config.GRAVITY)
        if c.grounded then
            if fallV < -Config.SPLAT_VZ then
                killSheep(i, "splat")
            elseif surfMat(math.floor(c.x), math.floor(c.y)) == GOO then
                killSheep(i, "goo")
            elseif c.x >= 88 then
                table.remove(Game.crits, i)
                State.saved = State.saved + 1
                State.score = State.score + 10
                Snd.play("square", 1319, 0.07, 0.3)
                Harness.count("saved")
            end
        end
    end
end

function Game.dig(x, y)
    local z = Vox.heightAt(x, y) - 1
    local removed = Vox.carve(x, y, z, Config.DIG_R)
    Harness.count("digs")
    Snd.play("noise", 200, 0.08, 0.3)
    for _ = 1, math.min(#removed, 4) do
        local v = removed[math.random(#removed)]
        spawnPart(v[1], v[2], v[3], v[4])
    end
end

function Game.blast(x, y)
    if State.blasts <= 0 then
        Snd.play("saw", 110, 0.06, 0.3)
        return
    end
    State.blasts = State.blasts - 1
    local z = Vox.heightAt(x, y) - 1
    local removed = Vox.carve(x, y, z, Config.BLAST_R)
    Harness.count("blastsused")
    Harness.count("carved", #removed)
    Snd.play("noise", 80, 0.3, 0.5)
    for _ = 1, math.min(#removed, 8) do
        local v = removed[math.random(#removed)]
        spawnPart(v[1], v[2], v[3], v[4])
    end
    -- sheep caught in the blast
    for i = #Game.crits, 1, -1 do
        local c = Game.crits[i]
        if (c.x - x) ^ 2 + (c.y - y) ^ 2 < 12 then killSheep(i, "blast") end
    end
end

local function resolveLevel()
    if State.saved >= State.quota then
        State.score = State.score + State.blasts * 5
        Snd.play("tri", 523, 0.1, 0.3)
        Util.after(0.12, function() Snd.play("tri", 784, 0.15, 0.3) end)
        Harness.count("clears")
        State.level = State.level + 1
        beginLevel()
    else
        Kit.setMode("over", 1.2)
        State.reason = "FLOCK LOST"
        State.newBest = Kit.saveBest(State.score)
        Music.stop()
        Harness.count("gameovers")
    end
end

local apT = 0
local function autoplay(dt)
    State.rate = 2.0
    apT = apT - dt
    if apT > 0 then return end
    apT = 1.2
    -- help the most-stuck sheep: blast (or dig) the ground just ahead
    local worst
    for _, c in ipairs(Game.crits) do
        if c.noProgT > 3.5 and (not worst or c.noProgT > worst.noProgT) then worst = c end
    end
    if worst then
        local x = math.floor(worst.x + 5)
        local y = math.floor(worst.y)
        -- never blast with a sheep in the kill radius; dig is harmless
        local safe = true
        for _, c in ipairs(Game.crits) do
            if (c.x - x) ^ 2 + (c.y - y) ^ 2 < 16 then safe = false end
        end
        if safe and State.blasts > 0 then
            Game.blast(x, y)
        else
            Game.dig(x, y)
        end
    end
end

function Game.update(dt)
    Music.update(dt)
    local inp = Input.state
    if Kit.mode == "title" then
        if inp.confirm then Game.startGame() end
        return
    end
    if Kit.mode == "over" then
        Kit.updateParts(Game.parts, dt)
        if Kit.modeT <= 0 and inp.confirm then Game.startGame() end
        return
    end
    Kit.updateParts(Game.parts, dt)
    if Kit.modeT > 0 then return end -- level banner
    -- run
    if inp.rate then State.rate = inp.rate end
    if Harness.enabled then autoplay(dt) end
    State.timer = State.timer - dt
    State.digCd = math.max(0, State.digCd - dt)
    if State.spawned < Config.TOTAL then
        State.spawnT = State.spawnT - dt * State.rate
        if State.spawnT <= 0 then
            State.spawnT = 1
            spawnSheep()
        end
    end
    updateSheep(dt)
    if not Harness.enabled then
        State.curX = Util.clamp(State.curX + inp.mvx, 2, Vox.W - 3)
        State.curY = Util.clamp(State.curY + inp.mvy, 2, Vox.D - 3)
        if inp.dig and State.digCd <= 0 then
            State.digCd = Config.DIG_CD
            Game.dig(State.curX, State.curY)
        end
        if inp.blast then Game.blast(State.curX, State.curY) end
    end
    if State.timer <= 0 then
        -- time up: everyone still out is lost
        State.dead = State.dead + #Game.crits
        Game.crits = {}
        State.spawned = Config.TOTAL
    end
    if State.spawned >= Config.TOTAL and #Game.crits == 0 then
        resolveLevel()
    end
end
