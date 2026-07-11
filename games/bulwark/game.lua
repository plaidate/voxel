-- Bulwark: Rampart in a voxel room. Build phase: place tetromino wall
-- pieces (cells are 2x2 voxel columns) to keep the ring around the keep
-- closed — checked by flood fill when the timer ends. Siege phase:
-- catapults on the east edge lob carving shells at your walls and keep
-- while you return fire with the keep cannon. Survive ROUNDS sieges.

Game = {
    cats = {},
    shells = {},
    parts = {},
    cannon = nil,
}

-- tense march: A-minor bass pulse under sparse minor-second stabs
local TRACK = {
    bpm = 116,
    bass = { 33, 0, 33, 0, 36, 0, 33, 0, 33, 0, 33, 0, 40, 0, 39, 0 },
    lead = { 0, 0, 0, 0, 69, 0, 0, 0, 0, 0, 0, 0, 68, 0, 69, 0 },
    hat = { 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0 },
}

Game.catModel = VoxModel.fromLayers({
    { "1.1", "111", "1.1" },
    { ".1.", ".1.", "..." },
    { "...", ".4.", "..." },
})

-- keep footprint: voxels x 23..29, y 29..35, cap at z=7
local KEEP = { x = 26.5, y = 32.5 }
Game.KEEP = KEEP

-- pieces in cell units (1 cell = 2x2 voxels)
local PIECES = {
    { { 0, 0 }, { 1, 0 }, { 2, 0 } },
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
    { { 0, 0 }, { 0, 1 }, { 1, 1 } },
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } },
    { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } },
    { { 0, 0 }, { 1, 0 } },
}

-- the starting wall ring, in cell coords (voxels x 18..35, y 24..41)
local ringCells = {}
for cx = 9, 17 do
    ringCells[#ringCells + 1] = { cx, 12 }
    ringCells[#ringCells + 1] = { cx, 20 }
end
for cy = 13, 19 do
    ringCells[#ringCells + 1] = { 9, cy }
    ringCells[#ringCells + 1] = { 17, cy }
end

local function rotCells(cells, rot)
    local out = {}
    local minx, miny = 99, 99
    for i, c in ipairs(cells) do
        local dx, dy = c[1], c[2]
        for _ = 1, rot % 4 do dx, dy = dy, -dx end
        out[i] = { dx, dy }
        if dx < minx then minx = dx end
        if dy < miny then miny = dy end
    end
    for _, c in ipairs(out) do
        c[1], c[2] = c[1] - minx, c[2] - miny
    end
    return out
end

function Game.pieceCells()
    return rotCells(PIECES[State.pieceIdx], State.pieceRot)
end

-- a cell is buildable when its 2x2 columns are soil or crater (no wall,
-- no keep) and inside the buildable region (east strip is catapult land)
function Game.cellFree(cx, cy)
    local x0, y0 = cx * 2, cy * 2
    if x0 < 2 or y0 < 2 or x0 + 1 > 77 or y0 + 1 > Vox.D - 3 then return false end
    for x = x0, x0 + 1 do
        for y = y0, y0 + 1 do
            if Vox.heightAt(x, y) > 2 then return false end
        end
    end
    return true
end

function Game.canPlace(cx, cy)
    for _, c in ipairs(Game.pieceCells()) do
        if not Game.cellFree(cx + c[1], cy + c[2]) then return false end
    end
    return true
end

local function buildCell(cx, cy)
    for x = cx * 2, cx * 2 + 1 do
        for y = cy * 2, cy * 2 + 1 do
            local h = Vox.heightAt(x, y)
            for z = h, 4 do Vox.set(x, y, z, z == 4 and 3 or 2) end
        end
    end
end

local function newPiece()
    State.pieceIdx = math.random(#PIECES)
    State.pieceRot = 0
end

function Game.placePiece()
    if not Game.canPlace(State.curX, State.curY) then
        Snd.play("saw", 110, 0.08, 0.3)
        return
    end
    local x0, x1 = 99, 0
    for _, c in ipairs(Game.pieceCells()) do
        local cx, cy = State.curX + c[1], State.curY + c[2]
        buildCell(cx, cy)
        if cx * 2 < x0 then x0 = cx * 2 end
        if cx * 2 + 1 > x1 then x1 = cx * 2 + 1 end
    end
    Vox.repaint(x0 - 1, x1 + 1)
    Snd.play("square", 523, 0.06, 0.25)
    Harness.count("placed")
    newPiece()
end

function Game.buildWorld()
    Vox.clear()
    -- indestructible soil course, then the etched-grid ground plane
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            Vox.set(x, y, 0, 2)
        end
    end
    Vox.floorGrid(2, 1)
    -- the keep
    for x = 23, 29 do
        for y = 29, 35 do
            for z = 2, 7 do Vox.set(x, y, z, z == 7 and 4 or 2) end
        end
    end
    -- the starting ring
    for _, c in ipairs(ringCells) do buildCell(c[1], c[2]) end
    Vox.buildBG()
end

-- flood fill from the courtyard: enclosed if it never reaches the edge.
-- Walls and the keep block at heightAt >= 4.
function Game.isEnclosed()
    local W, D = Vox.W, Vox.D
    local seen, queue = {}, {}
    local function push(x, y)
        local i = y * W + x
        if seen[i] then return end
        seen[i] = true
        if Vox.heightAt(x, y) < 4 then queue[#queue + 1] = i end
    end
    push(26, 27)
    push(26, 37)
    push(21, 32)
    push(31, 32)
    local head = 1
    while head <= #queue do
        local i = queue[head]
        head = head + 1
        local x, y = i % W, i // W
        if x == 0 or x == W - 1 or y == 0 or y == D - 1 then return false end
        push(x + 1, y)
        push(x - 1, y)
        push(x, y + 1)
        push(x, y - 1)
    end
    return true
end

local function setPhase(ph, t, banner)
    State.phase = ph
    State.phaseT = t or 0
    if banner then State.banner = banner end
end

local function beginBanner(nextPh, text)
    State.nextPhase = nextPh
    setPhase("banner", Config.BANNER_T, text)
end

local function spawnCats()
    Game.cats = {}
    local n = 1 + State.round
    for i = 1, n do
        Game.cats[i] = {
            x = 86.5 + math.random(0, 4),
            y = 6 + (i - 0.5) * (Vox.D - 12) / n + math.random(-3, 3),
            z = 2, vz = 0, hw = 1, grounded = true,
            fireT = 0.8 + math.random() * 2,
        }
    end
end

local function gameOver(reason, won)
    State.reason = reason
    State.won = won or false
    State.newBest = Kit.saveBest(State.score)
    Kit.setMode("over", 1.2)
    Music.stop()
    Harness.count(won and "wins" or "gameovers")
end

function Game.startGame()
    State.reset()
    Kit.setMode("play")
    Music.set(TRACK)
    Game.buildWorld()
    Game.cats = {}
    Game.shells = {}
    Game.parts = {}
    Game.cannon = { x = KEEP.x, y = KEEP.y, z = 8, az = 0, power = 0.5,
        charging = false, meterT = 0, cd = 0 }
    newPiece()
    beginBanner("build", "BUILD YOUR WALLS")
end

function Game.init()
    Kit.loadBest()
    Game.startGame()
    Kit.setMode("title")
end

-- shared solver opts; err is per-shot. The muzzle matches the old
-- bulwark sim: shells are solved from the mount, launched 1.5 up.
local solveOpts = {
    vmin = Config.VMIN, vmax = Config.VMAX,
    elevCos = Config.ELEV_COS, elevSin = Config.ELEV_SIN,
    iters = 8, errV = 2,
    muzzle = function(o)
        return o.x, o.y, o.z + 1.5
    end,
}

local function solveShot(origin, target, err)
    solveOpts.err = err
    return VoxProj.solve(origin, target, solveOpts)
end

local function fireShell(origin, az, v)
    local ca, sa = math.cos(az), math.sin(az)
    Game.shells[#Game.shells + 1] = VoxProj.launch(
        origin.x + ca * 1.5, origin.y + sa * 1.5, origin.z + 1.5, az, v,
        Config.ELEV_COS, Config.ELEV_SIN)
    Snd.play("tri", 131, 0.12, 0.35)
    Harness.count("shots")
end

local function explode(x, y, z)
    local removed = Vox.carve(x, y, z, Config.CARVE_R)
    Harness.count("carved", #removed)
    Snd.play("noise", 80, 0.3, 0.5)
    Kit.burst(Game.parts, removed, 8)
    Kit.spawnPart(Game.parts, x, y, z, { m = 4, speed = 14, vzMax = 14 })
    if (x - KEEP.x) ^ 2 + (y - KEEP.y) ^ 2 < 36 then
        State.keepHp = State.keepHp - 1
        State.keepFlash = 0.8
        Snd.play("saw", 98, 0.3, 0.5)
        Harness.count("keephits")
        if State.keepHp <= 0 then
            gameOver("CASTLE FELL")
            return
        end
    end
    for j = #Game.cats, 1, -1 do
        local c = Game.cats[j]
        if (c.x - x) ^ 2 + (c.y - y) ^ 2 < 12 then
            table.remove(Game.cats, j)
            State.score = State.score + 25
            for _ = 1, 6 do
                Kit.spawnPart(Game.parts, c.x, c.y, c.z + 1,
                    { m = math.random() < 0.5 and 1 or 4, speed = 14, vzMax = 14 })
            end
            Snd.play("square", 784, 0.1, 0.3)
            Harness.count("catskilled")
        end
    end
end

local function catTarget()
    local r = math.random()
    if r < 0.75 then
        local c = ringCells[math.random(#ringCells)]
        return c[1] * 2 + 1, c[2] * 2 + 1
    elseif r < 0.9 then
        return KEEP.x + math.random(-2, 2), KEEP.y + math.random(-2, 2)
    end
    return math.random(16, 40), math.random(22, 44)
end

local function updateShells(dt)
    for i = #Game.shells, 1, -1 do
        local s = Game.shells[i]
        local hit = VoxProj.step(s, dt, Config.GRAVITY)
        if hit then explode(s.x, s.y, s.z) end
        s.t = s.t - dt
        if hit or s.t <= 0 then table.remove(Game.shells, i) end
    end
end

local apT = 0
local catTgt = {}
local function autoplay(dt)
    if State.phase == "build" then
        apT = apT - dt
        if apT <= 0 then
            apT = 0.5
            for _ = 1, 6 do
                local c = ringCells[math.random(#ringCells)]
                local cx = c[1] + math.random(-1, 1)
                local cy = c[2] + math.random(-1, 1)
                State.pieceRot = math.random(0, 3)
                if Game.canPlace(cx, cy) then
                    State.curX, State.curY = cx, cy
                    Game.placePiece()
                    break
                end
            end
        end
    elseif State.phase == "siege" then
        local can = Game.cannon
        if can.cd <= 0 and #Game.cats > 0 then
            local c = Game.cats[math.random(#Game.cats)]
            local az, v = solveShot(can, c, Config.AP_ERR)
            fireShell(can, az, v)
            can.cd = Config.CANNON_CD + 0.4
        end
    end
end

local function endBuild()
    if Game.isEnclosed() then
        State.score = State.score + 50
        State.round = State.round + 1
        Harness.count("enclosed")
        beginBanner("siege", "SIEGE " .. State.round .. "!")
    else
        gameOver("WALLS OPEN")
    end
end

local function endSiege()
    Harness.count("sieges")
    if State.round >= Config.ROUNDS then
        gameOver("VICTORY", true)
    else
        beginBanner("build", "REBUILD")
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
    updateShells(dt)
    if Kit.mode ~= "play" then return end -- a shell may have ended the game
    -- catapults settle when the ground is carved from under them
    for _, c in ipairs(Game.cats) do
        VoxPhys.physZ(c, dt, Config.GRAVITY)
    end
    State.keepFlash = math.max(0, State.keepFlash - dt)
    local can = Game.cannon
    can.cd = math.max(0, can.cd - dt)
    if Harness.enabled then autoplay(dt) end
    local ph = State.phase
    if ph == "banner" then
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then
            if State.nextPhase == "siege" then spawnCats() end
            setPhase(State.nextPhase,
                State.nextPhase == "build" and Config.BUILD_T or Config.SIEGE_T)
        end
    elseif ph == "build" then
        if not Harness.enabled then
            State.curX = Util.clamp(State.curX + inp.mvx, 1, 37)
            State.curY = Util.clamp(State.curY + inp.mvy, 1, 30)
            if inp.rot ~= 0 then
                State.pieceRot = (State.pieceRot + inp.rot) % 4
            end
            if inp.place then Game.placePiece() end
        end
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 then endBuild() end
    elseif ph == "siege" then
        for _, c in ipairs(Game.cats) do
            c.fireT = c.fireT - dt
            if c.fireT <= 0 then
                c.fireT = 2.2 + math.random() * 1.4
                catTgt.x, catTgt.y = catTarget()
                local az, v = solveShot(c, catTgt, Config.CAT_ERR)
                fireShell(c, az, v)
            end
        end
        if not Harness.enabled then
            if inp.aim then can.az = inp.aim end
            if inp.chargeStart then can.charging, can.meterT = true, 0 end
            if can.charging then
                can.meterT = can.meterT + dt
                local phz = (can.meterT / Config.POWER_CADENCE) % 2
                can.power = phz <= 1 and phz or 2 - phz
                if inp.fire then
                    can.charging = false
                    if can.cd <= 0 then
                        fireShell(can, can.az,
                            Config.VMIN + can.power * (Config.VMAX - Config.VMIN))
                        can.cd = Config.CANNON_CD
                    end
                end
            end
        end
        State.phaseT = State.phaseT - dt
        if State.phaseT <= 0 or #Game.cats == 0 then endSiege() end
    end
end
