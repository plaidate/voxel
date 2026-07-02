-- Herd: drawing. Scene pattern shared with the other games, plus the dig
-- cursor, the release-rate dial and the flock tally.

local gfx = playdate.graphics

Draw = {}

local titleImg, overImg
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

local function drawSheep(c)
    drawShadow(c.x, c.y, 1)
    VoxModel.draw(Game.sheepModel, c.x, c.y, c.z)
    Vox.occlude(c.x - 1.5, c.x + 1.5, c.y, c.z, c.z + 2)
end

local function drawPart(q)
    Vox.drawBlock(q.x - 0.5, q.y, q.z, q.m)
    Vox.occlude(q.x - 1, q.x + 1, q.y, q.z, q.z + 1)
end

local function drawScene()
    Vox.drawBG()
    local list = {}
    for _, c in ipairs(Game.crits) do
        list[#list + 1] = { y = c.y, fn = drawSheep, arg = c }
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

local function drawCursor()
    local g = Vox.heightAt(State.curX, State.curY)
    local sx = Vox.OX + (State.curX - 2) * Vox.S
    local sy = Vox.OY + State.curY * Vox.TY - g * Vox.TZ - 2 * Vox.TY
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(sx, sy, 5 * Vox.S, 5 * Vox.TY)
end

local function drawHud()
    whiteText("HOME " .. State.saved .. "/" .. State.quota .. "   LOST " .. State.dead, 8, 3)
    whiteTextCentered("TIME " .. math.max(0, math.ceil(State.timer)) .. "s", 3)
    -- blast charges
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.BLASTS do
        local x = 400 - 12 * i
        if i <= State.blasts then
            gfx.fillRect(x, 5, 8, 8)
        else
            gfx.drawRect(x, 5, 8, 8)
        end
    end
    whiteText("LEVEL " .. State.level .. "  SCORE " .. State.score, 8, 222)
    -- release-rate dial
    whiteText("rate", 220, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(256, 226, 102, 8)
    local f = (State.rate - Config.RATE_MIN) / (Config.RATE_MAX - Config.RATE_MIN)
    gfx.fillRect(257, 227, math.floor(f * 100), 6)
    if State.phase == "run" and not Harness.enabled then
        drawCursor()
    end
    if State.phase == "banner" then
        panel(110, 100, 180, 26)
        whiteTextCentered(State.banner, 105)
    end
end

local function drawTitle()
    titleImg = titleImg or bigText("HERD")
    panel(46, 42, 308, 146)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = titleImg.width * 3
    titleImg:drawScaled(math.floor((400 - w) / 2), 50, 3)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("dig and blast a path - get the flock home", 112)
    whiteTextCentered("d-pad cursor / Ⓐ dig / Ⓑ blast", 130)
    whiteTextCentered("crank sets the release rate", 146)
    whiteTextCentered("press Ⓐ to start", 166)
end

local function drawOver()
    overImg = overImg or bigText("FLOCK LOST")
    panel(78, 70, 244, 86)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = overImg.width * 2
    overImg:drawScaled(math.floor((400 - w) / 2), 80, 2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("level " .. State.level .. " / score " .. State.score, 116)
    whiteTextCentered("Ⓐ again", 134)
end

function Draw.frame()
    drawScene()
    if State.mode == "title" then
        drawTitle()
    elseif State.mode == "over" then
        drawOver()
    else
        drawHud()
    end
end
