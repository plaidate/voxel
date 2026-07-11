-- Voxelspace: the renderer. Classic VoxelSpace (Comanche / s-macke)
-- rendering, cast column by column: each screen column marches one ray
-- front to back with growing depth steps and draws only slices that
-- rise above everything already drawn. Per-column rays terminate the
-- moment their column reaches the top of the screen, the z/1-z/fog
-- ladder is precomputed once, and adjacent same-shade slices merge into
-- a single fill. Shades are dither patterns lifted toward the white sky
-- with distance.

Draw = {}

local gfx = playdate.graphics
local sin, cos, floor = math.sin, math.cos, math.floor

-- 17 ordered-dither levels from a 4x4 Bayer matrix, 0=black .. 16=white
local PAT = {}
do
    local B = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
    for level = 0, 16 do
        local rows = {}
        for y = 1, 8 do
            local br, bits = B[(y - 1) % 4 + 1], 0
            for x = 0, 7 do
                if br[x % 4 + 1] < level then bits = bits | (1 << x) end
            end
            rows[y] = bits
        end
        PAT[level] = rows
    end
end

-- the depth ladder never changes: precompute z, the projection factor
-- and the fog level for every step (map-cell units fold 1/CELL in here
-- so the inner loop multiplies once per axis)
local NSTEPS, ZS, IZS, FOGS, FLAT
do
    local zs, izs, fogs, flat = {}, {}, {}, {}
    local z, dz, k = Config.ZNEAR, Config.DZ0, 0
    while z < Config.ZFAR do
        k = k + 1
        zs[k] = z / Config.CELL
        izs[k] = Config.SCALE / z
        local f = 0
        if z > Config.FOG1 then
            f = (z - Config.FOG1) // Config.FOGSTEP + 1
            if f > 4 then f = 4 end
        end
        fogs[k] = f
        -- past FLATZ haze wins over shading: one fixed shade, so a
        -- column's whole far tail merges into a single fill
        flat[k] = z > Config.FLATZ and Config.FLATSHADE or false
        z = z + dz
        dz = dz * Config.DZK
    end
    NSTEPS, ZS, IZS, FOGS, FLAT = k, zs, izs, fogs, flat
end

Draw.segs = 0

local function render()
    gfx.clear(gfx.kColorWhite)

    local cells = Map.cells
    local cols, colw = Config.COLS, Config.COLW
    local camh = State.alt
    local icell = 1 / Config.CELL
    local cx, cy = State.x * icell, State.y * icell
    local sa, ca = sin(State.ang), cos(State.ang)
    -- ray directions lerp across the 90-degree frustum, in map cells
    -- per unit depth (ZS is already in cell units)
    local lx, ly = -ca - sa, sa - ca
    local ddx = ((ca - sa) - lx) / cols
    local ddy = ((-sa - ca) - ly) / cols
    local horizon = Config.HORIZON + floor(State.pitch * 26)
    local nsteps, zs, izs, fogs, flat = NSTEPS, ZS, IZS, FOGS, FLAT
    local setPattern, fillRect = gfx.setPattern, gfx.fillRect
    local lastShade = -1
    local segs = 0

    -- highest screen point terrain could reach at each depth step this
    -- frame: once a column is already drawn above it, its ray is done
    local tops = Draw.tops or table.create(nsteps, 0)
    Draw.tops = tops
    local over = camh - Map.hmax
    for k = 1, nsteps do
        tops[k] = (over * izs[k]) // 1 + horizon
    end

    local dirx, diry = lx + ddx * 0.5, ly + ddy * 0.5
    for i = 0, cols - 1 do
        local yb = 240
        local runTop, runBot, runShade = 0, 0, -1
        local sx = i * colw
        for k = 1, nsteps do
            if tops[k] >= yb then break end -- nothing farther can show
            local z = zs[k]
            local v = cells[((cy + diry * z) // 1 & 255) * 256
                + ((cx + dirx * z) // 1 & 255) + 1]
            local sy = (camh - v // 32) * izs[k] // 1 + horizon
            if sy < yb then
                if sy < 0 then sy = 0 end
                -- fog lifts shades in four steps with depth, capped
                -- short of white so ridges never melt into the sky
                local s = flat[k]
                if not s then
                    s = (v & 31) + fogs[k]
                    if s > 14 then s = 14 end
                end
                if s == runShade then
                    runTop = sy -- extend the pending fill upward
                else
                    if runShade >= 0 then
                        if runShade ~= lastShade then
                            setPattern(PAT[runShade])
                            lastShade = runShade
                        end
                        fillRect(sx, runTop, colw, runBot - runTop)
                        segs = segs + 1
                    end
                    runTop, runBot, runShade = sy, yb, s
                end
                yb = sy
                if sy <= 0 then break end -- column full: ray done
            end
        end
        if runShade >= 0 then
            if runShade ~= lastShade then
                setPattern(PAT[runShade])
                lastShade = runShade
            end
            fillRect(sx, runTop, colw, runBot - runTop)
            segs = segs + 1
        end
        dirx = dirx + ddx
        diry = diry + ddy
    end
    gfx.setColor(gfx.kColorBlack)
    Draw.segs = segs
end

local function hud()
    Kit.panel(2, 222, 208, 16)
    Kit.text(string.format("ALT %3d  SPD %2d  HDG %3d",
        floor(State.alt),
        Input.state.boost and Config.BOOST or Config.SPEED,
        floor(math.deg(State.ang) % 360)), 6, 223)
end

function Draw.frame()
    render()
    if Kit.mode == "title" then
        Kit.title("VOXELSPACE", {
            "crank/left right steers, up down climbs",
            "hold Ⓐ to boost, Ⓑ new terrain",
            "press Ⓐ to fly",
        })
    else
        hud()
    end
end
