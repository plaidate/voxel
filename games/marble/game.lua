-- Marble: roll a ball down a tilted heightfield course from the west
-- pad to the white east pad. Slopes accelerate you (gradient of the
-- height map), steep faces bounce you, crests throw you airborne, goo
-- pools eat marbles. The crank winds a boost; A releases it.

local GOO = 1
local PAD = 4

-- rolling minimal: hypnotic A-minor arp over a spare root pulse
local TRACK = {
    bpm = 112,
    bass = { 33, 0, 0, 0, 0, 0, 0, 0, 33, 0, 0, 0, 40, 0, 0, 0 },
    lead = { 57, 0, 60, 0, 64, 0, 60, 0, 57, 0, 60, 0, 64, 0, 67, 0 },
    hat  = { 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0 },
}

Game = {
    ball = nil,
    parts = {},
}

Game.ballModel = VoxModel.fromLayers({
    { "44", "44" },
    { "44", "44" },
})

local function hAt(x, y)
    return Vox.heightAt(math.floor(x), math.floor(y))
end

local function surfAt(x, y)
    local _, m = Vox.surfaceAt(math.floor(x), math.floor(y))
    return m
end

function Game.buildCourse(course)
    Vox.clear()
    local W, D = Vox.W, Vox.D
    -- moguls and valleys (same RNG call order as the old inline loop)
    local bumps = {}
    for _ = 1, 8 + course do
        local cx = math.random(14, W - 15)
        local cy = math.random(6, D - 7)
        local r = math.random(6, 12)
        local h = (math.random() * 2 + 1.2) * (math.random() < 0.5 and 1 or -1)
        bumps[#bumps + 1] = { cx, cy, r, h }
    end
    local hm = Vox.bumpField(W, D, bumps)
    -- west-to-east tilt. Everything sits one higher than the old inline
    -- fill (which started at z=1 over an empty z=0): fromHeightmap fills
    -- from z=0, so +1 here keeps every column top exactly where it was.
    for y = 1, D do
        local row = hm[y]
        for x = 1, W do
            row[x] = row[x] + 10 - 7 * ((x - 1) / (W - 1))
        end
    end
    -- flat start and goal pads
    for x = 4, 12 do
        for y = D // 2 - 4, D // 2 + 4 do hm[y + 1][x + 1] = 10 end
    end
    for x = 83, 91 do
        for y = D // 2 - 5, D // 2 + 5 do hm[y + 1][x + 1] = 3 end
    end
    Vox.fromHeightmap(hm, { mat = 2, capMat = 3, capMin = 8, hmin = 2, hmax = 13 })
    -- the goal pad reads white
    for x = 83, 91 do
        for y = D // 2 - 5, D // 2 + 5 do
            Vox.set(x, y, Vox.heightAt(x, y) - 1, PAD)
        end
    end
    -- goo pools mid-course
    for _ = 1, 2 + course do
        local px = math.random(20, 74)
        local py = math.random(6, D - 7)
        local r = math.random(2, 4)
        for x = px - r, px + r do
            for y = py - r, py + r do
                if (x - px) ^ 2 + (y - py) ^ 2 <= r * r
                    and x > 14 and x < 80 and y > 1 and y < D - 2 then
                    local hh = hAt(x, y)
                    if hh >= 2 then Vox.set(x, y, hh - 1, GOO) end
                end
            end
        end
    end
    Vox.buildBG()
end

local function resetBall()
    Game.ball = {
        x = 8.5, y = Vox.D // 2 + 0.5, z = hAt(8, Vox.D // 2),
        vx = 0, vy = 0, vz = 0, grounded = true, charge = 0,
    }
end

local function beginCourse()
    Game.buildCourse(State.course)
    Game.parts = {}
    resetBall()
    State.timer = Config.COURSE_T
    Kit.setMode("play", Config.BANNER_T)
    State.banner = "COURSE " .. State.course
end

function Game.startGame()
    State.reset()
    Music.set(TRACK)
    beginCourse()
end

function Game.init()
    Kit.loadBest()
    Game.startGame()
    Kit.setMode("title")
end

local function gameOver(reason)
    Kit.setMode("over", 1.2)
    State.reason = reason
    State.newBest = Kit.saveBest(State.score)
    Music.stop()
    Harness.count("gameovers")
end

local function loseMarble()
    local b = Game.ball
    for _ = 1, 8 do Kit.spawnPart(Game.parts, b.x, b.y, b.z + 1, 4) end
    Snd.play("saw", 80, 0.3, 0.5)
    State.marbles = State.marbles - 1
    Harness.count("deaths")
    if State.marbles <= 0 then
        gameOver("OUT OF MARBLES")
    else
        resetBall()
    end
end

local function courseClear()
    State.score = State.score + 25 + math.ceil(State.timer) * 2
    Snd.play("square", 1047, 0.1, 0.3)
    Util.after(0.1, function() Snd.play("square", 1568, 0.15, 0.3) end)
    Harness.count("courses")
    State.course = State.course + 1
    beginCourse()
end

local function autoplay(dt, inp)
    local b = Game.ball
    b.charge = math.min(1, b.charge + 0.05)
    local dx, dy = 88 - b.x, Vox.D // 2 - b.y
    inp.mx = (dx > 2 and 1) or (dx < -2 and -1) or 0
    inp.my = (dy > 2 and 1) or (dy < -2 and -1) or 0
    local sp2 = b.vx * b.vx + b.vy * b.vy
    if b.grounded and sp2 < 16 and b.charge > 0.6 then
        inp.boost = true
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
    if Kit.modeT > 0 then return end -- course banner
    if Harness.enabled then autoplay(dt, inp) end
    local b = Game.ball
    b.charge = math.min(1, b.charge + (inp.charge or 0))
    if b.grounded then
        local gx = (hAt(b.x + 1, b.y) - hAt(b.x - 1, b.y)) / 2
        local gy = (hAt(b.x, b.y + 1) - hAt(b.x, b.y - 1)) / 2
        b.vx = b.vx + (-gx * Config.SLOPE_K + inp.mx * Config.STEER) * dt
        b.vy = b.vy + (-gy * Config.SLOPE_K + inp.my * Config.STEER) * dt
        local f = math.max(0, 1 - Config.FRICTION * dt)
        b.vx, b.vy = b.vx * f, b.vy * f
    else
        b.vx = b.vx + inp.mx * Config.STEER * 0.3 * dt
        b.vy = b.vy + inp.my * Config.STEER * 0.3 * dt
    end
    local sp = math.sqrt(b.vx * b.vx + b.vy * b.vy)
    if sp > Config.VMAX then
        b.vx, b.vy = b.vx * Config.VMAX / sp, b.vy * Config.VMAX / sp
    end
    if inp.boost and b.charge > 0.1 then
        local d = sp > 0.5 and sp or 1
        local bx = sp > 0.5 and b.vx / d or 1
        local by = sp > 0.5 and b.vy / d or 0
        b.vx = b.vx + bx * Config.BOOST * b.charge
        b.vy = b.vy + by * Config.BOOST * b.charge
        Snd.play("square", 440 + b.charge * 440, 0.1, 0.3)
        Harness.count("boosts")
        b.charge = 0
    end
    -- horizontal move with wall bounce
    local nx = b.x + b.vx * dt
    if hAt(nx, b.y) - b.z > 1.5 then
        b.vx = -b.vx * Config.BOUNCE
        Snd.play("tri", 220, 0.05, 0.2)
    else
        b.x = Util.clamp(nx, 1, Vox.W - 2)
    end
    local ny = b.y + b.vy * dt
    if hAt(b.x, ny) - b.z > 1.5 then
        b.vy = -b.vy * Config.BOUNCE
        Snd.play("tri", 220, 0.05, 0.2)
    else
        b.y = Util.clamp(ny, 1, Vox.D - 2)
    end
    -- vertical: follow ground, catch air off crests
    local g = hAt(b.x, b.y)
    if b.grounded then
        if g < b.z - 1.2 then
            b.grounded = false
            b.vz = 0
        else
            b.z = g
        end
    end
    if not b.grounded then
        b.vz = b.vz - Config.GRAVITY * dt
        b.z = b.z + b.vz * dt
        if b.z <= g then
            b.z = g
            b.vz = 0
            b.grounded = true
        end
    end
    if b.grounded then
        local m = surfAt(b.x, b.y)
        if m == GOO then
            loseMarble()
            return
        elseif m == PAD then
            courseClear()
            return
        end
    end
    State.timer = State.timer - dt
    if State.timer <= 0 then gameOver("TIME UP") end
end
