-- Rubble: drawing. Static terrain comes from Vox's background image; the
-- player, grubs, shots and debris paint back-to-front with Vox.drawBlock
-- and then Vox.occlude so pillars and walls cover them. HUD lives in the
-- black margins above and below the arena.

local gfx = playdate.graphics

Draw = {}

local titleImg, deadImg
local function bigText(text)
    local w, h = gfx.getTextSize(text)
    local img = gfx.image.new(w, h)
    gfx.pushContext(img)
    gfx.drawText(text, 0, 0)
    gfx.popContext()
    return img
end

local function drawShadow(x, y, hw)
    local g = Vox.heightAt(math.floor(x), math.floor(y))
    gfx.setPattern(Vox.PAT[1])
    local sx = math.floor(Vox.OX + (x - hw) * Vox.S + 0.5)
    local sy = math.floor(Vox.OY + y * Vox.TY - g * Vox.TZ + 0.5)
    gfx.fillRect(sx, sy, math.floor(hw * 2 * Vox.S + 0.5), Vox.TY)
end

local function drawPlayer()
    local p = Game.player
    if p.inv > 0 and math.floor(p.inv * 15) % 2 == 0 then
        return -- hit blink
    end
    drawShadow(p.x, p.y, 1.2)
    VoxModel.draw(Game.playerModel, p.x, p.y, p.z)
    -- gun barrel voxel in the aim direction
    local ca, sa = math.cos(p.aim), math.sin(p.aim)
    Vox.drawBlock(p.x + ca * 2 - 0.5, p.y + sa * 2, p.z + 1.5, 4)
    Vox.occlude(p.x - 2.5, p.x + 2.5, p.y, p.z, p.z + 4.5)
end

local function drawEnemy(e)
    drawShadow(e.x, e.y, 1)
    VoxModel.draw(Game.grubModel, e.x, e.y, e.z)
    Vox.occlude(e.x - 1.5, e.x + 1.5, e.y, e.z, e.z + 2)
end

local function drawShot(s)
    Vox.drawBlock(s.x - 0.5, s.y, s.z, 4)
    Vox.occlude(s.x - 1, s.x + 1, s.y, s.z, s.z + 1)
end

local function drawPart(q)
    Vox.drawBlock(q.x - 0.5, q.y, q.z, q.m)
    Vox.occlude(q.x - 1, q.x + 1, q.y, q.z, q.z + 1)
end

local function drawScene()
    Vox.drawBG()
    local list = {}
    local p = Game.player
    if p then
        list[#list + 1] = { y = p.y, fn = drawPlayer }
    end
    for _, e in ipairs(Game.enemies) do
        list[#list + 1] = { y = e.y, fn = drawEnemy, arg = e }
    end
    for _, s in ipairs(Game.shots) do
        list[#list + 1] = { y = s.y, fn = drawShot, arg = s }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = drawPart, arg = q }
    end
    table.sort(list, function(a, b) return a.y < b.y end)
    for i = 1, #list do
        local d = list[i]
        d.fn(d.arg)
    end
end

local function drawReticle()
    local p = Game.player
    gfx.setColor(gfx.kColorWhite)
    local ca, sa = math.cos(p.aim), math.sin(p.aim)
    for i = 5, 11, 3 do
        local rx = math.floor(Vox.OX + (p.x + ca * i) * Vox.S + 0.5)
        local ry = math.floor(Vox.OY + (p.y + sa * i) * Vox.TY - (p.z + 1.5) * Vox.TZ + 0.5)
        gfx.fillRect(rx, ry, 2, 2)
    end
end

local function panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

local function whiteText(text, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(text, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function whiteTextCentered(text, y)
    local w = gfx.getTextSize(text)
    whiteText(text, math.floor((400 - w) / 2), y)
end

local function drawHud()
    local pp = Game.player
    if pp then Kit.marker(pp.x, pp.y, pp.z + 4, State.t or 0) end
    drawReticle()
    whiteText("SCORE " .. State.score, 8, 3)
    whiteText("WAVE " .. State.wave, 176, 3)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MAX_HP do
        local x = 400 - 14 * i
        if i <= State.hp then
            gfx.fillRect(x, 5, 9, 9)
        else
            gfx.drawRect(x, 5, 9, 9)
        end
    end
    if playdate.isCrankDocked and playdate.isCrankDocked() and not Harness.enabled then
        whiteText("crank to aim", 154, 224)
    end
end

local function drawTitle()
    titleImg = titleImg or bigText("RUBBLE")
    panel(50, 48, 300, 130)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = titleImg.width * 3
    titleImg:drawScaled(math.floor((400 - w) / 2), 56, 3)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("waves of grubs - carve the arena", 118)
    whiteTextCentered("d-pad move / crank aim / Ⓑ jump", 136)
    whiteTextCentered("press Ⓐ to start", 156)
end

local function drawDead()
    deadImg = deadImg or bigText("WRECKED")
    panel(78, 70, 244, 86)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = deadImg.width * 2
    deadImg:drawScaled(math.floor((400 - w) / 2), 80, 2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("score " .. State.score .. " / wave " .. State.wave, 116)
    whiteTextCentered("Ⓐ again", 134)
end

function Draw.frame()
    drawScene()
    if State.mode == "title" then
        drawTitle()
    elseif State.mode == "dead" then
        drawDead()
        whiteText("SCORE " .. State.score, 8, 3)
    else
        drawHud()
    end
end
