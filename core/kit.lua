-- Voxel core: shared game scaffolding — white HUD text, panels, cached
-- big text, actor shadows, debris particles and the painter-sorted draw
-- list. Games built after the first five lean on this instead of
-- duplicating it.

local gfx = playdate.graphics

Kit = {}

local cache = {}

function Kit.bigText(text)
    local img = cache[text]
    if not img then
        local w, h = gfx.getTextSize(text)
        img = gfx.image.new(w, h)
        gfx.pushContext(img)
        gfx.drawText(text, 0, 0)
        gfx.popContext()
        cache[text] = img
    end
    return img
end

function Kit.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

function Kit.text(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function Kit.centered(t, y)
    local w = gfx.getTextSize(t)
    Kit.text(t, math.floor((400 - w) / 2), y)
end

function Kit.bigCentered(text, y, scale)
    local img = Kit.bigText(text)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    img:drawScaled(math.floor((400 - img.width * scale) / 2), y, scale)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- title screen: big name + instruction lines (last line is the prompt)
function Kit.title(name, lines)
    local h = 78 + #lines * 18 + 14
    Kit.panel(46, 42, 308, h)
    Kit.bigCentered(name, 50, 3)
    for i, line in ipairs(lines) do
        Kit.centered(line, 94 + i * 18)
    end
end

-- game-over screen: big reason + sub lines
function Kit.over(reason, lines)
    Kit.panel(78, 70, 244, 50 + #lines * 18)
    Kit.bigCentered(reason, 80, 2)
    for i, line in ipairs(lines) do
        Kit.centered(line, 98 + i * 18)
    end
end

function Kit.shadow(x, y, hw)
    local g = Vox.heightAt(math.floor(x), math.floor(y))
    gfx.setPattern(Vox.PAT[1])
    local sx = math.floor(Vox.OX + (x - hw) * Vox.S + 0.5)
    local sy = math.floor(Vox.OY + y * Vox.TY - g * Vox.TZ + 0.5)
    gfx.fillRect(sx, sy, math.floor(hw * 2 * Vox.S + 0.5), Vox.TY)
end

function Kit.spawnPart(list, x, y, z, m)
    if #list > 40 then return end
    list[#list + 1] = {
        x = x, y = y, z = z,
        vx = (math.random() - 0.5) * 13,
        vy = (math.random() - 0.5) * 13,
        vz = math.random() * 9 + 4,
        t = 0.6 + math.random() * 0.4,
        m = m,
    }
end

-- debris burst from Vox.carve()'s removed list
function Kit.burst(list, removed, n)
    for _ = 1, math.min(#removed, n) do
        local v = removed[math.random(#removed)]
        Kit.spawnPart(list, v[1], v[2], v[3], v[4])
    end
end

function Kit.updateParts(list, dt)
    for i = #list, 1, -1 do
        local q = list[i]
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
        if q.t <= 0 then table.remove(list, i) end
    end
end

function Kit.drawPart(q)
    Vox.drawBlock(q.x - 0.5, q.y, q.z, q.m)
    Vox.occlude(q.x - 1, q.x + 1, q.y, q.z, q.z + 1)
end

-- bold player locator: bobbing black-outlined white chevron above the
-- actor, drawn after everything so it survives occlusion
function Kit.marker(wx, wy, wz, t)
    local sx = math.floor(Vox.OX + wx * Vox.S + Vox.S / 2 + 0.5)
    local sy = math.floor(Vox.OY + wy * Vox.TY - wz * Vox.TZ + 0.5)
        - 8 + math.floor(math.sin((t or 0) * 5) * 2 + 0.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(sx - 5, sy - 8, sx + 5, sy - 8, sx, sy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(sx - 3, sy - 7, sx + 3, sy - 7, sx, sy - 2)
end

-- run a painter list of {y=, fn=, arg=}
function Kit.drawSorted(list)
    table.sort(list, function(a, b) return a.y < b.y end)
    for i = 1, #list do
        local d = list[i]
        d.fn(d.arg)
    end
end
