-- Voxel core: the room engine. A Voxatron-style fixed room — a W x D x H
-- grid of shaded voxels in a 3/4 projection on the 1-bit screen.
--
--   world x -> screen x (S px per voxel)
--   world y (depth, 0 = back) -> screen y down (TY px per step)
--   world z (height, 0 = floor) -> screen y up (TZ px per step)
--
-- Each voxel draws as a TY-tall top face and a TZ-tall front face, shaded
-- with dither patterns by material (1 dark .. 4 white; front face uses the
-- next-darker pattern). Static terrain is rendered once into a background
-- image; Vox.carve() removes a sphere and repaints only the dirty column
-- strip. Dynamic things draw per frame with Vox.drawBlock, then call
-- Vox.occlude so terrain in front of them (pillars, walls) covers them.

local gfx = playdate.graphics

Vox = {
    W = 96, D = 64, H = 16,
    S = 4, TY = 2, TZ = 4,
    OX = 8, OY = 86,
    bg = nil,
}

-- dither patterns, 0 = black .. 4 = white
local PAT = {
    [0] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    [1] = { 0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00 },
    [2] = { 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55 },
    [3] = { 0xDD, 0xFF, 0x77, 0xFF, 0xDD, 0xFF, 0x77, 0xFF },
    [4] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
}
Vox.PAT = PAT

local W, D, H = Vox.W, Vox.D, Vox.H
local S, TY, TZ = Vox.S, Vox.TY, Vox.TZ
local floor = math.floor
local map = {}    -- [(y*W + x)*H + z + 1] = material or nil
local colTop = {} -- [y*W + x + 1] = highest solid z >= 1 (0 if column is floor only)

function Vox.clear()
    map = {}
    colTop = {}
end

local function recalcColTop(x, y)
    local base = (y * W + x) * H
    for z = H - 1, 1, -1 do
        if map[base + z + 1] then
            colTop[y * W + x + 1] = z
            return
        end
    end
    colTop[y * W + x + 1] = 0
end

function Vox.set(x, y, z, m)
    if x < 0 or x >= W or y < 0 or y >= D or z < 0 or z >= H then return end
    map[(y * W + x) * H + z + 1] = m
    if z >= 1 then
        local ci = y * W + x + 1
        local ct = colTop[ci] or 0
        if m and z > ct then
            colTop[ci] = z
        elseif not m and z == ct then
            recalcColTop(x, y)
        end
    end
end

function Vox.get(x, y, z)
    if x < 0 or x >= W or y < 0 or y >= D or z < 0 or z >= H then return nil end
    return map[(y * W + x) * H + z + 1]
end

-- solid for movement/shots: outside the room horizontally or below the
-- floor counts as solid, above the ceiling is open
function Vox.solid(x, y, z)
    if z < 0 then return true end
    if z >= H then return false end
    if x < 0 or x >= W or y < 0 or y >= D then return true end
    return map[(y * W + x) * H + z + 1] ~= nil
end

-- standing height at integer column (top of the highest solid voxel + 1)
function Vox.heightAt(x, y)
    if x < 0 or x >= W or y < 0 or y >= D then return H end
    local base = (y * W + x) * H
    for z = H - 1, 0, -1 do
        if map[base + z + 1] then return z + 1 end
    end
    return 0
end

-- one voxel block drawn directly to the current context (floats fine)
function Vox.drawBlock(px, py, pz, m)
    local sx = floor(Vox.OX + px * S + 0.5)
    local sy = floor(Vox.OY + py * TY - pz * TZ + 0.5)
    gfx.setPattern(PAT[m])
    gfx.fillRect(sx, sy, S, TY)
    gfx.setPattern(PAT[m - 1])
    gfx.fillRect(sx, sy + TY, S, TZ)
end

-- repaint columns x0..x1 of the static world into the current context.
-- Draws only visible faces (top face if nothing above, front face if
-- nothing in front), back to front so nearer voxels overwrite.
function Vox.renderStrip(x0, x1)
    if x0 < 0 then x0 = 0 end
    if x1 >= W then x1 = W - 1 end
    local cx = Vox.OX + x0 * S
    local cw = (x1 - x0 + 1) * S
    gfx.setClipRect(cx, 0, cw, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(cx, 0, cw, 240)
    local OX, OY = Vox.OX, Vox.OY
    local WH = W * H
    for y = 0, D - 1 do
        local rowBase = y * W * H
        local sy0 = OY + y * TY
        for x = x0, x1 do
            local base = rowBase + x * H
            local sx = OX + x * S
            for z = 0, H - 1 do
                local m = map[base + z + 1]
                if m then
                    local sy = sy0 - z * TZ
                    if z == H - 1 or not map[base + z + 2] then
                        gfx.setPattern(PAT[m])
                        gfx.fillRect(sx, sy, S, TY)
                    end
                    if y == D - 1 or not map[base + WH + z + 1] then
                        gfx.setPattern(PAT[m - 1])
                        gfx.fillRect(sx, sy + TY, S, TZ)
                    end
                end
            end
        end
    end
    gfx.clearClipRect()
end

-- build (or rebuild) the full background image
function Vox.buildBG()
    Vox.bg = gfx.image.new(400, 240, gfx.kColorBlack)
    gfx.pushContext(Vox.bg)
    Vox.renderStrip(0, W - 1)
    gfx.popContext()
end

function Vox.drawBG()
    Vox.bg:draw(0, 0)
end

-- repaint columns of the background image after Vox.set changes (carve
-- calls this itself; games that add terrain call it directly)
function Vox.repaint(x0, x1)
    if not Vox.bg then return end
    gfx.pushContext(Vox.bg)
    Vox.renderStrip(x0, x1)
    gfx.popContext()
end

-- remove a sphere of voxels (the floor z=0 is indestructible), repaint the
-- dirty strip, return the removed voxels as {x,y,z,m} for particle bursts
function Vox.carve(cx, cy, cz, r)
    cx, cy, cz = floor(cx + 0.5), floor(cy + 0.5), floor(cz + 0.5)
    local removed = {}
    local r2 = r * r
    for x = math.max(0, cx - r), math.min(W - 1, cx + r) do
        for y = math.max(0, cy - r), math.min(D - 1, cy + r) do
            local base = (y * W + x) * H
            local touched = false
            for z = math.max(1, cz - r), math.min(H - 1, cz + r) do
                local dx, dy, dz = x - cx, y - cy, z - cz
                if dx * dx + dy * dy + dz * dz <= r2 then
                    local m = map[base + z + 1]
                    if m then
                        map[base + z + 1] = nil
                        touched = true
                        removed[#removed + 1] = { x, y, z, m }
                    end
                end
            end
            if touched then recalcColTop(x, y) end
        end
    end
    if #removed > 0 then Vox.repaint(cx - r - 1, cx + r + 1) end
    return removed
end

-- after drawing a dynamic thing spanning world x [wx0,wx1] at depth wy,
-- redraw any terrain in front of it (y > wy, z >= 1) so pillars and walls
-- correctly cover it. The flat floor never occludes, so columns with
-- colTop == 0 are skipped and this is cheap.
function Vox.occlude(wx0, wx1, wy, wz0, wz1)
    wz1 = wz1 or wz0 + 4
    local x0 = math.max(0, floor(wx0))
    local x1 = math.min(W - 1, floor(wx1))
    local OX, OY = Vox.OX, Vox.OY
    local entBottom = OY + wy * TY - wz0 * TZ + TY + TZ
    local entTop = OY + wy * TY - wz1 * TZ
    local WH = W * H
    for y = floor(wy) + 1, D - 1 do
        local sy0 = OY + y * TY
        if sy0 - H * TZ > entBottom then break end
        -- only heights whose faces can overlap the actor's screen span
        local zlo = math.ceil((sy0 - entBottom) / TZ)
        if zlo < 1 then zlo = 1 end
        local zhi = floor((sy0 + TY + TZ - entTop) / TZ)
        for x = x0, x1 do
            local ct = colTop[y * W + x + 1] or 0
            if ct > zhi then ct = zhi end
            if ct >= zlo then
                local base = (y * W + x) * H
                local sx = OX + x * S
                for z = zlo, ct do
                    local m = map[base + z + 1]
                    if m then
                        local sy = sy0 - z * TZ
                        if z == H - 1 or not map[base + z + 2] then
                            gfx.setPattern(PAT[m])
                            gfx.fillRect(sx, sy, S, TY)
                        end
                        if y == D - 1 or not map[base + WH + z + 1] then
                            gfx.setPattern(PAT[m - 1])
                            gfx.fillRect(sx, sy + TY, S, TZ)
                        end
                    end
                end
            end
        end
    end
end
