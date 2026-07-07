-- Voxelspace: terrain generation and the flight model. This demo does
-- not use the Vox room engine -- the world is a wrapping 256x256
-- heightmap in Map.cells, one flat array of packed ints (height*32 +
-- shade 0..16). The renderer (draw.lua) marches it Comanche-style.

Game = {}
Map = { cells = nil }

local floor, random = math.floor, math.random
local SIZE = 256

-- Wrapping value noise: four bilinear-interpolated random lattices,
-- halving amplitude, summed then stretched to the full 0..1 range.
function Game.genMap(seed)
    math.randomseed(seed)
    local n = SIZE * SIZE
    local acc = table.create(n, 0)
    for i = 1, n do acc[i] = 0 end
    local octaves = { { 64, 1.0 }, { 32, 0.4 }, { 16, 0.15 }, { 8, 0.05 } }
    for _, oct in ipairs(octaves) do
        local cell, amp = oct[1], oct[2]
        local ln = SIZE // cell
        local lat = table.create(ln * ln, 0)
        for i = 1, ln * ln do lat[i] = random() end
        local inv = 1 / cell
        local i = 1
        for y = 0, SIZE - 1 do
            local fy = y * inv
            local y0 = floor(fy); fy = fy - y0
            local r0 = y0 * ln
            local r1 = ((y0 + 1) % ln) * ln
            for x = 0, SIZE - 1 do
                local fx = x * inv
                local x0 = floor(fx); fx = fx - x0
                local x1 = (x0 + 1) % ln
                local a, b = lat[r0 + x0 + 1], lat[r0 + x1 + 1]
                local c, d = lat[r1 + x0 + 1], lat[r1 + x1 + 1]
                local top = a + (b - a) * fx
                acc[i] = acc[i] + (top + (c + (d - c) * fx - top) * fy) * amp
                i = i + 1
            end
        end
    end

    local lo, hi = 10, -10
    for i = 1, n do
        local v = acc[i]
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    local stretch = 1 / (hi - lo)

    -- world heights first (slope shading needs the west neighbor)
    local hmax, water, snow = Config.HMAX, Config.WATER, Config.SNOW
    local waterH = floor(water * water * hmax)
    local hw = table.create(n, 0)
    local norm = table.create(n, 0)
    for i = 1, n do
        local v = (acc[i] - lo) * stretch
        norm[i] = v
        hw[i] = v <= water and waterH or floor(v * v * hmax)
    end

    -- one smoothing pass (cross kernel) so single-cell height steps
    -- don't alias into see-through slits and skyline spikes where the
    -- renderer's sample stride exceeds one map cell
    local sm = table.create(n, 0)
    for i = 1, n do
        local x = (i - 1) % SIZE
        local w = x == 0 and i + SIZE - 1 or i - 1
        local e = x == SIZE - 1 and i - SIZE + 1 or i + 1
        local up = i - SIZE; if up < 1 then up = up + n end
        local dn = i + SIZE; if dn > n then dn = dn - n end
        sm[i] = (hw[i] * 4 + hw[w] + hw[e] + hw[up] + hw[dn]) // 8
    end
    hw = sm

    local hmax2 = 0
    for i = 1, n do
        if hw[i] > hmax2 then hmax2 = hw[i] end
    end
    Map.hmax = hmax2

    -- pack height + shade (17 dither levels, 0=black..16=white): dark
    -- water, land banded 4..10 by elevation, snowcaps 12, +-3 for
    -- lit/shadowed slopes (light from the west)
    local cells = table.create(n, 0)
    local landInv = 1 / (1 - water)
    for i = 1, n do
        local v, h = norm[i], hw[i]
        local s
        if v <= water then
            s = 2
        else
            s = v > snow and 12 or 4 + floor((v - water) * landInv * 6.99)
            local lit = (h - hw[i % SIZE == 1 and i + SIZE - 1 or i - 1]) // 2
            if lit > 3 then lit = 3 elseif lit < -3 then lit = -3 end
            s = s + lit
            if s < 3 then s = 3 elseif s > 13 then s = 13 end
        end
        cells[i] = h * 32 + s
    end
    Map.cells = cells
end

-- x, y in world units (CELL world units per map cell)
function Game.heightAt(x, y)
    local k = 1 / Config.CELL
    return Map.cells[(floor(y * k) & 255) * 256 + (floor(x * k) & 255) + 1] // 32
end

function Game.init()
    State.reset()
    Game.genMap(State.seed)
end

function Game.update(dt)
    local s = Input.state

    if State.mode == "title" then
        if s.confirm then
            State.mode = "fly"
            Harness.count("flights")
        end
        return
    end

    if s.regen then
        State.seed = State.seed + 1
        Game.genMap(State.seed)
        Harness.count("regens")
    end

    State.ang = State.ang + s.dturn * Config.DTURN * dt
        + math.rad(s.crank * Config.TURN)

    local speed = s.boost and Config.BOOST or Config.SPEED
    local wrap = SIZE * Config.CELL
    State.x = (State.x - math.sin(State.ang) * speed * dt) % wrap
    State.y = (State.y - math.cos(State.ang) * speed * dt) % wrap
    State.dist = State.dist + speed * dt

    State.alt = State.alt + s.climb * Config.CLIMB * dt
    local ground = Game.heightAt(State.x, State.y) + Config.CLEARANCE
    if State.alt < ground then State.alt = ground end
    if State.alt > Config.ALTMAX then State.alt = Config.ALTMAX end

    -- cosmetic horizon tilt toward the climb input
    State.pitch = State.pitch + (s.climb - State.pitch) * Config.PITCH_LERP * dt

    Harness.set("dist", floor(State.dist))
end
