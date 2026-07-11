-- Rubble: arena, actors and simulation. Waves of grubs converge on the
-- player; shots and blocked grubs carve the terrain via Vox.carve.

Game = {
    player = nil,
    enemies = {},
    shots = {},
    parts = {},
}

-- sparse rumble: lone sub-bass hits with the occasional noise tick
local TRACK = {
    bpm = 84,
    bass = { 28, 0, 0, 0, 0, 0, 31, 0, 0, 0, 0, 0, 26, 0, 0, 0 },
    hat = { 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0 },
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

Game.grubModel = VoxModel.fromLayers({
    { "11", "11", "11" },
    { "..", "..", "44" },
})

local pendingSpawns = 0

function Game.buildWorld()
    Vox.clear()
    -- mid-gray floor with an etched dark grid so white/black actors pop
    Vox.floorGrid(2, 1, 8, 0)
    -- rim walls, 2 thick, 3 high, light capstones
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            if x < 2 or x >= Vox.W - 2 or y < 2 or y >= Vox.D - 2 then
                Vox.column(x, y, 3, 2, 3)
            end
        end
    end
    -- pillars
    for _, p in ipairs({ { 18, 14, 7 }, { 18, 46, 6 }, { 46, 29, 8 }, { 74, 14, 6 }, { 74, 46, 7 } }) do
        for x = p[1], p[1] + 3 do
            for y = p[2], p[2] + 3 do
                Vox.column(x, y, p[3], 2, 4)
            end
        end
    end
    -- low rubble mounds
    for _, m in ipairs({ { 32, 10 }, { 60, 50 }, { 30, 44 }, { 64, 12 }, { 10, 30 }, { 84, 32 } }) do
        for x = m[1], m[1] + 2 do
            for y = m[2], m[2] + 2 do
                Vox.set(x, y, 1, 1)
            end
        end
        Vox.set(m[1] + 1, m[2] + 1, 2, 1)
    end
    Vox.buildBG()
end

function Game.startRun()
    State.reset()
    Game.buildWorld()
    Util.clearPending()
    Music.set(TRACK)
    Game.player = {
        x = Vox.W / 2, y = Vox.D / 2 + 6, z = 1, vz = 0,
        hw = 1.1, grounded = true,
        aim = -math.pi / 2, cd = 0, inv = 0, kbx = 0, kby = 0,
    }
    Game.enemies = {}
    Game.shots = {}
    Game.parts = {}
    pendingSpawns = 0
end

function Game.init()
    Kit.loadBest()
    Game.startRun()
    Kit.setMode("title")
end

local tryMove = VoxPhys.tryMove

local function physZ(e, dt)
    VoxPhys.physZ(e, dt, Config.GRAVITY)
end

-- carve a crater and throw debris
function Game.boom(x, y, z, r)
    local removed = Vox.carve(x, y, z, r)
    if #removed > 0 then
        Harness.count("carved", #removed)
        Snd.play("noise", 110, 0.15, 0.4)
        Kit.burst(Game.parts, removed, 8)
    else
        Snd.play("noise", 220, 0.05, 0.2)
        Kit.spawnPart(Game.parts, x, y, z, { m = 4, speed = 14, vzMax = 14 })
    end
end

function Game.spawnEnemy()
    pendingSpawns = pendingSpawns - 1
    if Kit.mode ~= "play" then return end
    local x, y
    local side = math.random(4)
    if side == 1 then
        x, y = math.random(6, Vox.W - 7), 5
    elseif side == 2 then
        x, y = math.random(6, Vox.W - 7), Vox.D - 6
    elseif side == 3 then
        x, y = 5, math.random(6, Vox.D - 7)
    else
        x, y = Vox.W - 6, math.random(6, Vox.D - 7)
    end
    local e = {
        x = x, y = y, z = Vox.heightAt(x, y), vz = 0,
        hw = 0.9, grounded = true, chew = Config.CHEW_PERIOD,
    }
    Game.enemies[#Game.enemies + 1] = e
    Kit.spawnPart(Game.parts, x, y, e.z + 1, { m = 4, count = 4, speed = 14, vzMax = 14 })
    Harness.count("spawns")
end

function Game.killEnemy(j)
    local e = table.remove(Game.enemies, j)
    State.score = State.score + 10
    Snd.play("tri", 392, 0.08, 0.3)
    Util.after(0.07, function() Snd.play("tri", 196, 0.1, 0.3) end)
    for _ = 1, 6 do
        Kit.spawnPart(Game.parts, e.x, e.y, e.z + 1,
            { m = math.random() < 0.5 and 1 or 4, speed = 14, vzMax = 14 })
    end
    Harness.count("kills")
end

function Game.hurtPlayer(nx, ny)
    local p = Game.player
    local d = math.sqrt(nx * nx + ny * ny)
    if d > 0.01 then nx, ny = nx / d, ny / d end
    p.kbx, p.kby = nx * Config.KNOCKBACK, ny * Config.KNOCKBACK
    p.inv = Config.IFRAMES
    State.hp = State.hp - 1
    Snd.play("saw", 98, 0.2, 0.4)
    Harness.count("hurt")
    if State.hp <= 0 then
        State.newBest = Kit.saveBest(State.score)
        Kit.setMode("dead", 1.0)
        Music.stop()
        for _ = 1, 12 do
            Kit.spawnPart(Game.parts, p.x, p.y, p.z + 1,
                { m = math.random(2, 4), speed = 14, vzMax = 14 })
        end
        Harness.count("gameovers")
    end
end

local function updatePlayer(dt, inp)
    local p = Game.player
    p.cd = math.max(0, p.cd - dt)
    p.inv = math.max(0, p.inv - dt)
    if inp.aim then p.aim = inp.aim end
    local dx, dy = inp.mx, inp.my
    if dx ~= 0 and dy ~= 0 then
        dx, dy = dx * 0.7071, dy * 0.7071
    end
    local nx = p.x + (dx * Config.MOVE_SPEED + p.kbx) * dt
    local ny = p.y + (dy * Config.MOVE_SPEED + p.kby) * dt
    p.kbx, p.kby = p.kbx * 0.85, p.kby * 0.85
    tryMove(p, nx, p.y)
    tryMove(p, p.x, ny)
    if inp.jump and p.grounded then
        p.vz = Config.JUMP_VEL
        p.grounded = false
    end
    physZ(p, dt)
    if inp.fire and p.cd == 0 then
        p.cd = Config.FIRE_COOLDOWN
        local ca, sa = math.cos(p.aim), math.sin(p.aim)
        Game.shots[#Game.shots + 1] = {
            x = p.x + ca * 2.2, y = p.y + sa * 2.2, z = p.z + 1.5,
            dx = ca, dy = sa, d = 0,
        }
        Snd.play("square", 740, 0.06, 0.25)
        Harness.count("shots")
    end
end

local function updateShots(dt)
    local floor = math.floor
    for i = #Game.shots, 1, -1 do
        local s = Game.shots[i]
        local step = Config.SHOT_SPEED * dt / 2
        local dead = false
        for _ = 1, 2 do
            s.x = s.x + s.dx * step
            s.y = s.y + s.dy * step
            s.d = s.d + step
            for j = #Game.enemies, 1, -1 do
                local e = Game.enemies[j]
                local ddx, ddy = e.x - s.x, e.y - s.y
                if ddx * ddx + ddy * ddy < 2.6 and math.abs(e.z + 1 - s.z) < 2.5 then
                    Game.killEnemy(j)
                    dead = true
                    break
                end
            end
            if dead then break end
            if Vox.solid(floor(s.x), floor(s.y), floor(s.z)) then
                Game.boom(s.x, s.y, s.z, Config.CARVE_R)
                dead = true
                break
            end
            if s.d > Config.SHOT_RANGE then
                dead = true
                break
            end
        end
        if dead then table.remove(Game.shots, i) end
    end
end

local function updateEnemies(dt)
    local p = Game.player
    local sp = Config.ENEMY_SPEED + State.wave * Config.ENEMY_SPEED_WAVE
    for _, e in ipairs(Game.enemies) do
        local dx, dy = p.x - e.x, p.y - e.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.01 then dx, dy = dx / d, dy / d end
        local movedX = dx ~= 0 and tryMove(e, e.x + dx * sp * dt, e.y)
        local movedY = dy ~= 0 and tryMove(e, e.x, e.y + dy * sp * dt)
        if not movedX and not movedY then
            e.chew = e.chew - dt
            if e.chew <= 0 then
                e.chew = Config.CHEW_PERIOD
                Game.boom(e.x + dx * 2, e.y + dy * 2, e.z + 1, Config.CHEW_R)
                Harness.count("chews")
            end
        end
        physZ(e, dt)
        if p.inv == 0 and Kit.mode == "play" then
            local cx, cy = p.x - e.x, p.y - e.y
            if cx * cx + cy * cy < 4.5 and math.abs(p.z - e.z) < 2 then
                Game.hurtPlayer(cx, cy)
            end
        end
    end
end

local function updateWaves()
    if #Game.enemies == 0 and pendingSpawns == 0 then
        State.wave = State.wave + 1
        Harness.set("wave", State.wave)
        if State.wave > 1 then State.score = State.score + 25 end
        local n = Config.WAVE_BASE + State.wave
        pendingSpawns = n
        for i = 1, n do
            Util.after(0.6 + i * Config.SPAWN_GAP, Game.spawnEnemy)
        end
        Snd.play("tri", 523, 0.09, 0.25)
        Util.after(0.1, function() Snd.play("tri", 784, 0.12, 0.25) end)
    end
end

function Game.update(dt)
    Music.update(dt)
    local inp = Input.state
    if Kit.mode == "title" then
        if inp.confirm then
            Game.startRun()
            Kit.setMode("play")
        end
        return
    end
    if Kit.mode == "dead" then
        Kit.updateParts(Game.parts, dt)
        if Kit.modeT <= 0 and inp.confirm then
            Game.startRun()
            Kit.setMode("play")
        end
        return
    end
    State.t = State.t + dt -- drives the locator marker's bob
    updatePlayer(dt, inp)
    updateShots(dt)
    updateEnemies(dt)
    Kit.updateParts(Game.parts, dt)
    updateWaves()
end
