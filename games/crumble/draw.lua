-- Crumble: drawing. Same scene pattern as Rubble (bg blit, painter-sorted
-- actors, Vox.occlude) plus screen shake on slime rises and a spring
-- charge meter in the bottom margin.

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
        return
    end
    drawShadow(p.x, p.y, 1.2)
    VoxModel.draw(Game.playerModel, p.x, p.y, p.z)
    Vox.occlude(p.x - 2, p.x + 2, p.y, p.z, p.z + 4)
end

local function drawGem(gm)
    local m = (math.sin(gm.phase * 8) > 0) and 4 or 3
    Vox.drawBlock(gm.x - 0.5, gm.y, gm.z, m)
    Vox.occlude(gm.x - 1, gm.x + 1, gm.y, gm.z, gm.z + 1)
end

local function drawPart(q)
    Vox.drawBlock(q.x - 0.5, q.y, q.z, q.m)
    Vox.occlude(q.x - 1, q.x + 1, q.y, q.z, q.z + 1)
end

local function drawScene()
    Vox.drawBG()
    local list = {}
    if Game.player then
        list[#list + 1] = { y = Game.player.y, fn = drawPlayer }
    end
    for _, gm in ipairs(Game.gems) do
        list[#list + 1] = { y = gm.y, fn = drawGem, arg = gm }
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
    whiteText("SCORE " .. State.score, 8, 3)
    whiteText("SLIME " .. State.slimeLevel, 176, 3)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MAX_HP do
        local x = 400 - 14 * i
        if i <= State.hp then
            gfx.fillRect(x, 5, 9, 9)
        else
            gfx.drawRect(x, 5, 9, 9)
        end
    end
    -- spring charge meter
    local p = Game.player
    whiteText("spring", 90, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(140, 226, 122, 8)
    gfx.fillRect(141, 227, math.floor(p.charge * 120), 6)
end

local function drawTitle()
    titleImg = titleImg or bigText("CRUMBLE")
    panel(50, 48, 300, 130)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = titleImg.width * 3
    titleImg:drawScaled(math.floor((400 - w) / 2), 56, 3)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("the slime rises - stay high, grab gems", 118)
    whiteTextCentered("d-pad move / Ⓑ hop / crank + Ⓐ spring", 136)
    whiteTextCentered("press Ⓐ to start", 156)
end

local function drawDead()
    deadImg = deadImg or bigText("CONSUMED")
    panel(78, 70, 244, 86)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = deadImg.width * 2
    deadImg:drawScaled(math.floor((400 - w) / 2), 80, 2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("score " .. State.score .. " / slime " .. State.slimeLevel, 116)
    whiteTextCentered("Ⓐ again", 134)
end

function Draw.frame()
    if State.shake > 0 then
        playdate.display.setOffset(math.random(-2, 2), math.random(-1, 1))
    else
        playdate.display.setOffset(0, 0)
    end
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
