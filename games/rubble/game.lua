-- Rubble: arena, actors and simulation. Waves of grubs converge on the
-- player; shots and blocked grubs carve the terrain via Vox.carve.

local snd = {
    shoot = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    boom = playdate.sound.synth.new(playdate.sound.kWaveNoise),
    hurt = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
    kill = playdate.sound.synth.new(playdate.sound.kWaveTriangle),
}

Game = {
    player = nil,
    enemies = {},
    shots = {},
    parts = {},
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
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            local m = (x % 8 == 0 or y % 8 == 0) and 1 or 2
            Vox.set(x, y, 0, m)
        end
    end
    -- rim walls, 2 thick, 3 high, light capstones
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            if x < 2 or x >= Vox.W - 2 or y < 2 or y >= Vox.D - 2 then
                for z = 1, 3 do Vox.set(x, y, z, z == 3 and 3 or 2) end
            end
        end
    end
    -- pillars
    for _, p in ipairs({ { 18, 14, 7 }, { 18, 46, 6 }, { 46, 29, 8 }, { 74, 14, 6 }, { 74, 46, 7 } }) do
        for x = p[1], p[1] + 3 do
            for y = p[2], p[2] + 3 do
                for z = 1, p[3] do Vox.set(x, y, z, z == p[3] and 4 or 2) end
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
    Game.startRun()
    State.mode = "title"
end

local tryMove = VoxPhys.tryMove

local function physZ(e, dt)
    VoxPhys.physZ(e, dt, Config.GRAVITY)
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

-- carve a crater and throw debris
function Game.boom(x, y, z, r)
    local removed = Vox.carve(x, y, z, r)
    if #removed > 0 then
        Harness.count("carved", #removed)
        snd.boom:playNote(110, 0.4, 0.15)
        for _ = 1, math.min(#removed, 8) do
            local v = removed[math.random(#removed)]
            Game.spawnPart(v[1], v[2], v[3], v[4])
        end
    else
        snd.boom:playNote(220, 0.2, 0.05)
        Game.spawnPart(x, y, z, 4)
    end
end

function Game.spawnEnemy()
    pendingSpawns = pendingSpawns - 1
    if State.mode ~= "play" then return end
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
    for _ = 1, 4 do Game.spawnPart(x, y, e.z + 1, 4) end
    Harness.count("spawns")
end

function Game.killEnemy(j)
    local e = table.remove(Game.enemies, j)
    State.score = State.score + 10
    snd.kill:playNote(392, 0.3, 0.08)
    Util.after(0.07, function() snd.kill:playNote(196, 0.3, 0.1) end)
    for _ = 1, 6 do Game.spawnPart(e.x, e.y, e.z + 1, math.random() < 0.5 and 1 or 4) end
    Harness.count("kills")
end

function Game.hurtPlayer(nx, ny)
    local p = Game.player
    local d = math.sqrt(nx * nx + ny * ny)
    if d > 0.01 then nx, ny = nx / d, ny / d end
    p.kbx, p.kby = nx * Config.KNOCKBACK, ny * Config.KNOCKBACK
    p.inv = Config.IFRAMES
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
        snd.shoot:playNote(740, 0.25, 0.06)
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
        if p.inv == 0 and State.mode == "play" then
            local cx, cy = p.x - e.x, p.y - e.y
            if cx * cx + cy * cy < 4.5 and math.abs(p.z - e.z) < 2 then
                Game.hurtPlayer(cx, cy)
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
            q.vx, q.vy = q.vx * 0.6, q.vy * 0.6
        end
        if q.t <= 0 then table.remove(Game.parts, i) end
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
        snd.kill:playNote(523, 0.25, 0.09)
        Util.after(0.1, function() snd.kill:playNote(784, 0.25, 0.12) end)
    end
end

function Game.update(dt)
    local inp = Input.state
    if State.mode == "title" then
        if inp.confirm then
            Game.startRun()
            State.mode = "play"
        end
        return
    end
    if State.mode == "dead" then
        State.t = State.t + dt
        updateParts(dt)
        if State.t > 1 and inp.confirm then
            Game.startRun()
            State.mode = "play"
        end
        return
    end
    updatePlayer(dt, inp)
    updateShots(dt)
    updateEnemies(dt)
    updateParts(dt)
    updateWaves()
end
