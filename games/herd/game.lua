-- Herd: pocket Lemmings. Sheep pour from the west platform and march
-- east to the gate; ridges block them, goo pools scare them into
-- detours, long falls splat them. Your only tools remove terrain: dig
-- notches, blast gaps, even drain goo by carving off its surface. Crank
-- sets the release rate.

local snd = {
    pop = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    home = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    dig = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    boom = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    die = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
    clear = playdate.sound.synth.new(playdate.sound.kWaveTriangle),
}

local GOO = 1 -- surface material sheep refuse to walk on (and die in)

Game = {
    crits = {},
    parts = {},
}

Game.sheepModel = VoxModel.fromLayers({
    { "44", "44", "44" },
    { "..", "..", "11" },
})

local tryMove = VoxPhys.tryMove

local function surfaceAt(x, y)
    return Vox.get(x, y, Vox.heightAt(x, y) - 1)
end

function Game.genLevel(level)
    Vox.clear()
    -- bedrock + 3 courses of soil; light grid etched on top
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            Vox.set(x, y, 0, 2)
            Vox.set(x, y, 1, 2)
            Vox.set(x, y, 2, 2)
            Vox.set(x, y, 3, (x % 8 == 0 or y % 8 == 0) and 3 or 2)
        end
    end
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
    State.phase = "banner"
    State.phaseT = Config.BANNER_T
    State.banner = "LEVEL " .. State.level .. " - SAVE " .. State.quota
end

function Game.startGame()
    State.reset()
    State.mode = "play"
    beginLevel()
end

function Game.init()
    Game.startGame()
    State.mode = "title"
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

local function spawnSheep()
    State.spawned = State.spawned + 1
    local y = Vox.D // 2 + math.random(-4, 4)
    Game.crits[#Game.crits + 1] = {
        x = 6, y = y + 0.5, z = Vox.heightAt(6, y), vz = 0,
        hw = 0.8, grounded = true,
        side = math.random() < 0.5 and 1 or -1, bestX = 6, noProgT = 0,
    }
    snd.pop:playNote(880, 0.25, 0.05)
    Harness.count("spawned")
end

local function killSheep(i, why)
    local c = table.remove(Game.crits, i)
    State.dead = State.dead + 1
    for _ = 1, 5 do Game.spawnPart(c.x, c.y, c.z + 1, why == "goo" and 1 or 4) end
    snd.die:playNote(why == "goo" and 65 or 110, 0.4, 0.15)
    Harness.count("deaths")
end

-- goo ahead reads as a wall to a sheep
local function walkable(c, nx, ny)
    if surfaceAt(math.floor(nx), math.floor(ny)) == GOO then return false end
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
            elseif surfaceAt(math.floor(c.x), math.floor(c.y)) == GOO then
                killSheep(i, "goo")
            elseif c.x >= 88 then
                table.remove(Game.crits, i)
                State.saved = State.saved + 1
                State.score = State.score + 10
                snd.home:playNote(1319, 0.3, 0.07)
                Harness.count("saved")
            end
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
        end
        if q.t <= 0 then table.remove(Game.parts, i) end
    end
end

function Game.dig(x, y)
    local z = Vox.heightAt(x, y) - 1
    local removed = Vox.carve(x, y, z, Config.DIG_R)
    Harness.count("digs")
    snd.dig:playNote(200, 0.3, 0.08)
    for _ = 1, math.min(#removed, 4) do
        local v = removed[math.random(#removed)]
        Game.spawnPart(v[1], v[2], v[3], v[4])
    end
end

function Game.blast(x, y)
    if State.blasts <= 0 then
        snd.die:playNote(110, 0.3, 0.06)
        return
    end
    State.blasts = State.blasts - 1
    local z = Vox.heightAt(x, y) - 1
    local removed = Vox.carve(x, y, z, Config.BLAST_R)
    Harness.count("blastsused")
    Harness.count("carved", #removed)
    snd.boom:playNote(80, 0.5, 0.3)
    for _ = 1, math.min(#removed, 8) do
        local v = removed[math.random(#removed)]
        Game.spawnPart(v[1], v[2], v[3], v[4])
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
        snd.clear:playNote(523, 0.3, 0.1)
        Util.after(0.12, function() snd.clear:playNote(784, 0.3, 0.15) end)
        Harness.count("clears")
        State.level = State.level + 1
        beginLevel()
    else
        State.mode = "over"
        State.reason = "FLOCK LOST"
        State.phaseT = 1.2
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
    local inp = Input.state
    if State.mode == "title" then
        if inp.confirm then Game.startGame() end
        return
    end
    if State.mode == "over" then
        State.phaseT = math.max(0, State.phaseT - dt)
        updateParts(dt)
        if State.phaseT <= 0 and inp.confirm then Game.startGame() end
        return
    end
    updateParts(dt)
    if State.phase == "banner" then
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then State.phase = "run" end
        return
    end
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
