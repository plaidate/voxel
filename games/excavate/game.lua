-- Excavate: dig into a stratified mound for buried fossils. Digging uses
-- the tunnel-aware physics (VoxPhys.tryMoveTun/physZTun) so you can
-- actually walk the tunnels you carve — but every dig settles unsupported
-- voxels, and greedy tunnels drop their roofs on you. Fossils are
-- anchored in the strata: extract them by proximity intact (15) or crack
-- them with a careless pick (5).

-- deep-mine minor: a slow A-minor pulse far below, sparse hollow answers
local TRACK = {
    bpm = 84,
    bass = { 33, 0, 0, 0, 36, 0, 0, 0, 31, 0, 0, 0, 36, 0, 40, 0 },
    lead = { 0, 0, 57, 0, 0, 0, 60, 0, 0, 0, 55, 0, 64, 0, 0, 0 },
    hat  = { 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0 },
}

local FOSSIL = 4

Game = {
    player = nil,
    fossils = {},
    parts = {},
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

function Game.buildMound(level)
    Vox.clear()
    Vox.floorGrid(2, 3, 8, 0)
    -- max-combined domes; strata: dark deep, light surface
    local hm = {}
    for i = 0, Vox.W * Vox.D - 1 do hm[i] = 0 end
    local domes = { { 44, 30, 27, 11 } }
    for _ = 1, 4 do
        domes[#domes + 1] = { math.random(26, 62), math.random(16, 46),
            math.random(9, 15), math.random(4, 7) }
    end
    for _, d in ipairs(domes) do
        local cx, cy, r, h = d[1], d[2], d[3], d[4]
        for x = math.max(0, cx - r), math.min(Vox.W - 1, cx + r) do
            for y = math.max(0, cy - r), math.min(Vox.D - 1, cy + r) do
                local d2 = ((x - cx) ^ 2 + (y - cy) ^ 2) / (r * r)
                if d2 < 1 then
                    local i = y * Vox.W + x
                    local v = h * (1 - d2)
                    if v > hm[i] then hm[i] = v end
                end
            end
        end
    end
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            local hh = math.floor(math.min(hm[y * Vox.W + x], Vox.H - 3))
            for z = 1, hh do
                Vox.set(x, y, z, z >= 6 and 3 or (z >= 3 and 2 or 1))
            end
        end
    end
    -- bury fossils (2x2 clusters of white voxels, anchored)
    Game.fossils = {}
    local n = Config.FOSSILS_BASE + level
    for _ = 1, 90 do
        if #Game.fossils >= n then break end
        local fx = math.random(26, 60)
        local fy = math.random(14, 46)
        local hh = Vox.heightAt(fx, fy)
        if hh >= 5 then
            local ok = true
            for _, f in ipairs(Game.fossils) do
                if (f.x - fx) ^ 2 + (f.y - fy) ^ 2 < 81 then ok = false end
            end
            if ok then
                -- fossils live in the deep strata, where undermining works
                local z = math.random(2, math.min(5, hh - 3))
                local cells = {}
                for dx = 0, 1 do
                    for dy = 0, 1 do
                        cells[#cells + 1] = { fx + dx, fy + dy, z }
                        Vox.set(fx + dx, fy + dy, z, FOSSIL)
                    end
                end
                Game.fossils[#Game.fossils + 1] =
                    { x = fx + 0.5, y = fy + 0.5, z = z, cells = cells, collected = false }
            end
        end
    end
    State.left = #Game.fossils
    Vox.buildBG()
end

local function moveFossilCell(x, y, z, wz)
    for _, f in ipairs(Game.fossils) do
        if not f.collected then
            for _, c in ipairs(f.cells) do
                if c[1] == x and c[2] == y and c[3] == z then
                    c[3] = wz
                    if wz < f.z then f.z = wz end
                    return
                end
            end
        end
    end
end

-- drop unsupported voxels straight down — fossils fall too (undermine
-- one and it drops to your tunnel floor); returns how many fell and
-- whether any fell beside the player
local function settle(x0, x1, y0, y1)
    local p = Game.player
    local fell, near = 0, false
    for x = math.max(0, x0), math.min(Vox.W - 1, x1) do
        for y = math.max(0, y0), math.min(Vox.D - 1, y1) do
            local wz = 1
            for z = 1, Vox.H - 1 do
                local m = Vox.get(x, y, z)
                if m then
                    if wz < z then
                        Vox.set(x, y, wz, m)
                        Vox.set(x, y, z, nil)
                        if m == FOSSIL then moveFossilCell(x, y, z, wz) end
                        fell = fell + 1
                        if math.abs(x - p.x) < 3 and math.abs(y - p.y) < 3 then
                            near = true
                        end
                    end
                    wz = wz + 1
                end
            end
        end
    end
    return fell, near
end

local function beginShift()
    Game.buildMound(State.level)
    Game.parts = {}
    Game.player = {
        x = 44, y = 56, z = 1, vz = 0, hw = 1.1, grounded = true,
        az = -math.pi / 2, inv = 0, digCd = 0,
    }
    State.timer = Config.SHIFT_T
    Kit.setMode("play", Config.BANNER_T)
    State.banner = "SHIFT " .. State.level .. " - " .. State.left .. " FOSSILS"
end

function Game.startGame()
    State.reset()
    beginShift()
end

function Game.init()
    Kit.loadBest()
    Music.set(TRACK)
    Game.startGame()
    Kit.setMode("title")
end

local function gameOver(reason)
    Kit.setMode("over", 1.2)
    State.reason = reason
    Kit.saveBest(State.score)
    Harness.count("gameovers")
end

local function hurt()
    local p = Game.player
    if p.inv > 0 then return end
    p.inv = Config.IFRAMES
    State.hp = State.hp - 1
    Snd.play("saw", 90, 0.25, 0.5)
    Harness.count("hurt")
    if State.hp <= 0 then gameOver("BURIED") end
end

local function collectFossil(f, intact)
    f.collected = true
    local x0, x1 = Vox.W, 0
    for _, c in ipairs(f.cells) do
        if Vox.get(c[1], c[2], c[3]) == FOSSIL then
            Vox.set(c[1], c[2], c[3], nil)
        end
        if c[1] < x0 then x0 = c[1] end
        if c[1] > x1 then x1 = c[1] end
    end
    settle(x0 - 1, x1 + 1, math.floor(f.y) - 2, math.floor(f.y) + 2)
    Vox.repaint(x0 - 2, x1 + 2)
    State.score = State.score + (intact and 15 or 5)
    State.left = State.left - 1
    Snd.play("square", intact and 1047 or 392, 0.08, 0.3)
    for _ = 1, 6 do Kit.spawnPart(Game.parts, f.x, f.y, f.z + 1, 4) end
    Harness.count(intact and "fossils" or "cracked")
    if State.left <= 0 then
        State.score = State.score + 25
        State.level = State.level + 1
        Snd.play("tri", 784, 0.15, 0.3)
        Harness.count("clears")
        beginShift()
    end
end

local function checkCracked()
    for _, f in ipairs(Game.fossils) do
        if not f.collected then
            for _, c in ipairs(f.cells) do
                if Vox.get(c[1], c[2], c[3]) ~= FOSSIL then
                    collectFossil(f, false)
                    break
                end
            end
        end
        if Kit.mode ~= "play" then return end
    end
end

-- is there standing headroom (hr voxels) for the full footprint at z?
local function footClear(x, y, hw, z, hr)
    local floor = math.floor
    for dz = 0, hr - 1 do
        for cy = floor(y - hw), floor(y + hw) do
            for cx = floor(x - hw), floor(x + hw) do
                if Vox.solid(cx, cy, z + dz) then return false end
            end
        end
    end
    return true
end

function Game.dig()
    local p = Game.player
    if p.digCd > 0 then return end
    p.digCd = Config.DIG_CD
    local ca, sa = math.cos(p.az), math.sin(p.az)
    local tx, ty = p.x + ca * 2.5, p.y + sa * 2.5
    local cz
    if Vox.solid(math.floor(tx), math.floor(ty), math.floor(p.z + 0.5)) then
        cz = p.z + 1 -- into the face ahead
    else
        -- open ground: dig into the target spot's own surface (a real
        -- pit even when aiming downslope)
        local sz = VoxPhys.support(math.floor(tx), math.floor(ty), p.z + 2)
        cz = math.max(1, sz - 1)
    end
    local removed = Vox.carve(tx, ty, cz, Config.DIG_R)
    Snd.play("noise", 180, 0.09, 0.3)
    Kit.burst(Game.parts, removed, 5)
    Harness.count("digs")
    checkCracked()
    if Kit.mode ~= "play" then return end
    local cx, cy = math.floor(tx + 0.5), math.floor(ty + 0.5)
    local fell, near = settle(cx - 3, cx + 3, cy - 3, cy + 3)
    if fell > 0 then
        Vox.repaint(cx - 4, cx + 4)
        if fell > 6 then
            Snd.play("noise", 55, 0.3, 0.5)
            Harness.count("caveins")
            if near then hurt() end
        end
    end
    -- buried by the collapse? Free the player into the nearest air
    -- pocket ABOVE (first z with footprint headroom, standing on its
    -- floor via supportAt), tunnels intact — never teleport through
    -- solid rock to the column top. Only a fully packed column falls
    -- back to the surface.
    if Vox.solid(math.floor(p.x), math.floor(p.y), math.floor(p.z) + 1) then
        local freed
        for z = math.floor(p.z), Vox.H - 1 do
            if footClear(p.x, p.y, p.hw, z, 3) then
                freed = z
                break
            end
        end
        if freed then
            p.z = VoxPhys.supportAt(p.x, p.y, p.hw, freed)
        else
            p.z = VoxPhys.groundAt(p.x, p.y, p.hw)
        end
        p.vz = 0
        hurt()
    end
end

local apDigT = 0
local function autoplay(dt, inp)
    local p = Game.player
    local best, bd
    for _, f in ipairs(Game.fossils) do
        if not f.collected then
            local d = (f.x - p.x) ^ 2 + (f.y - p.y) ^ 2
            if not bd or d < bd then bd, best = d, f end
        end
    end
    if not best then return end
    local dx, dy = best.x - p.x, best.y - p.y
    inp.aim = math.atan(dy, dx)
    inp.mx = (dx > 1.2 and 1) or (dx < -1.2 and -1) or 0
    inp.my = (dy > 1.2 and 1) or (dy < -1.2 and -1) or 0
    -- truly within reach (vertically too): stop swinging, walk it in.
    -- A fossil still overhead needs more undermining, so keep digging.
    if bd < 25 then
        for _, c in ipairs(best.cells) do
            if math.abs(c[3] - p.z) < 3 then return end
        end
    end
    apDigT = apDigT - dt
    if apDigT <= 0 then
        apDigT = 0.2
        inp.dig = true
    end
    if math.random() < 0.01 then inp.jump = true end
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
    if Kit.modeT > 0 then return end -- shift banner
    if Harness.enabled then autoplay(dt, inp) end
    local p = Game.player
    p.inv = math.max(0, p.inv - dt)
    p.digCd = math.max(0, p.digCd - dt)
    if inp.aim then p.az = inp.aim end
    local dx, dy = inp.mx, inp.my
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.7071, dy * 0.7071 end
    VoxPhys.tryMoveTun(p, p.x + dx * Config.SPEED * dt, p.y, 3)
    VoxPhys.tryMoveTun(p, p.x, p.y + dy * Config.SPEED * dt, 3)
    if inp.jump and p.grounded then
        p.vz = Config.JUMP_VEL
        p.grounded = false
    end
    VoxPhys.physZTun(p, dt, Config.GRAVITY, 3)
    if inp.dig then Game.dig() end
    if Kit.mode ~= "play" then return end
    -- proximity extraction (any cell within reach)
    for _, f in ipairs(Game.fossils) do
        if not f.collected then
            for _, c in ipairs(f.cells) do
                if math.abs(c[1] + 0.5 - p.x) < 3.5
                    and math.abs(c[2] + 0.5 - p.y) < 3.5
                    and math.abs(c[3] - p.z) < 3 then
                    collectFossil(f, true)
                    break
                end
            end
            if Kit.mode ~= "play" then return end
        end
    end
    -- sparkle hints from exposed fossil faces
    if math.random() < 0.08 then
        local f = Game.fossils[math.random(#Game.fossils)]
        if f and not f.collected then
            local c = f.cells[math.random(#f.cells)]
            if not Vox.solid(c[1], c[2], c[3] + 1) then
                Kit.spawnPart(Game.parts, c[1], c[2], c[3] + 1, 4)
            end
        end
    end
    State.timer = State.timer - dt
    if State.timer <= 0 then gameOver("SHIFT OVER") end
end
