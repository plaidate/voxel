-- Marble: roll a ball down a tilted heightfield course from the west
-- pad to the white east pad. Slopes accelerate you (gradient of the
-- height map), steep faces bounce you, crests throw you airborne, goo
-- pools eat marbles. The crank winds a boost; A releases it.

local snd = {
    boost = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    bounce = playdate.sound.synth.new(playdate.sound.kWaveTriangle),
    goal = playdate.sound.synth.new(playdate.sound.kWaveSquare),
    die = playdate.sound.synth.new(playdate.sound.kWaveSawtooth),
}

local GOO = 1
local PAD = 4

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
    return Vox.get(math.floor(x), math.floor(y), hAt(x, y) - 1)
end

function Game.buildCourse(course)
    Vox.clear()
    local W, D = Vox.W, Vox.D
    local hm = {}
    for x = 0, W - 1 do
        for y = 0, D - 1 do
            hm[y * W + x] = 9 - 7 * (x / (W - 1))
        end
    end
    -- moguls and valleys
    for _ = 1, 8 + course do
        local cx = math.random(14, W - 15)
        local cy = math.random(6, D - 7)
        local r = math.random(6, 12)
        local h = (math.random() * 2 + 1.2) * (math.random() < 0.5 and 1 or -1)
        for x = math.max(0, cx - r), math.min(W - 1, cx + r) do
            for y = math.max(0, cy - r), math.min(D - 1, cy + r) do
                local d2 = ((x - cx) ^ 2 + (y - cy) ^ 2) / (r * r)
                if d2 < 1 then
                    local i = y * W + x
                    hm[i] = hm[i] + h * (1 - d2)
                end
            end
        end
    end
    -- flat start and goal pads
    for x = 4, 12 do
        for y = D // 2 - 4, D // 2 + 4 do hm[y * W + x] = 9 end
    end
    for x = 83, 91 do
        for y = D // 2 - 5, D // 2 + 5 do hm[y * W + x] = 2 end
    end
    for x = 0, W - 1 do
        for y = 0, D - 1 do
            local hh = math.floor(Util.clamp(hm[y * W + x], 1, Vox.H - 4))
            for z = 1, hh do
                local m = 2
                if z == hh then
                    m = hh >= 7 and 3 or 2
                    if x >= 83 and x <= 91 and math.abs(y - D // 2) <= 5 then
                        m = PAD
                    end
                end
                Vox.set(x, y, z, m)
            end
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
    State.phase = "banner"
    State.phaseT = Config.BANNER_T
    State.banner = "COURSE " .. State.course
end

function Game.startGame()
    State.reset()
    State.mode = "play"
    beginCourse()
end

function Game.init()
    Game.startGame()
    State.mode = "title"
end

local function gameOver(reason)
    State.mode = "over"
    State.reason = reason
    State.phaseT = 1.2
    Harness.count("gameovers")
end

local function loseMarble()
    local b = Game.ball
    for _ = 1, 8 do Kit.spawnPart(Game.parts, b.x, b.y, b.z + 1, 4) end
    snd.die:playNote(80, 0.5, 0.3)
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
    snd.goal:playNote(1047, 0.3, 0.1)
    Util.after(0.1, function() snd.goal:playNote(1568, 0.3, 0.15) end)
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
    local b = Game.ball
    b.charge = math.min(1, b.charge + (inp.charge or 0))
    local g = hAt(b.x, b.y)
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
        snd.boost:playNote(440 + b.charge * 440, 0.3, 0.1)
        Harness.count("boosts")
        b.charge = 0
    end
    -- horizontal move with wall bounce
    local nx = b.x + b.vx * dt
    if hAt(nx, b.y) - b.z > 1.5 then
        b.vx = -b.vx * Config.BOUNCE
        snd.bounce:playNote(220, 0.2, 0.05)
    else
        b.x = Util.clamp(nx, 1, Vox.W - 2)
    end
    local ny = b.y + b.vy * dt
    if hAt(b.x, ny) - b.z > 1.5 then
        b.vy = -b.vy * Config.BOUNCE
        snd.bounce:playNote(220, 0.2, 0.05)
    else
        b.y = Util.clamp(ny, 1, Vox.D - 2)
    end
    -- vertical: follow ground, catch air off crests
    g = hAt(b.x, b.y)
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
    if State.mode ~= "play" then return end
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
