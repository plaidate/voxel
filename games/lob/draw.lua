-- Lob: drawing. Scene pattern shared with the other games, plus per-side
-- HUD (hearts + round pips), a wind gauge, aim dots for whichever mortar
-- is aiming, and the power meter.

local gfx = playdate.graphics

Draw = {}

local titleImg, winImg, loseImg
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

local function drawUnit(u)
    if u.flash > 0 and math.floor(u.flash * 15) % 2 == 0 then
        return
    end
    drawShadow(u.x, u.y, 1.2)
    VoxModel.draw(u.model, u.x, u.y, u.z)
    Vox.occlude(u.x - 2, u.x + 2, u.y, u.z, u.z + 4)
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
    for _, u in ipairs({ Game.you, Game.foe }) do
        list[#list + 1] = { y = u.y, fn = drawUnit, arg = u }
    end
    if Game.shot then
        list[#list + 1] = { y = Game.shot.y, fn = drawShot, arg = Game.shot }
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

-- aim dots for whichever mortar is choosing its shot
local function drawAim()
    local u = State.turn == "you" and Game.you or Game.foe
    gfx.setColor(gfx.kColorWhite)
    local ca, sa = math.cos(u.az), math.sin(u.az)
    for i = 5, 14, 3 do
        local rx = math.floor(Vox.OX + (u.x + ca * i) * Vox.S + 0.5)
        local ry = math.floor(Vox.OY + (u.y + sa * i) * Vox.TY - (u.z + 2) * Vox.TZ + 0.5)
        gfx.fillRect(rx, ry, 2, 2)
    end
end

local function hearts(u, x, dir)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MAX_HP do
        local hx = x + dir * 14 * (i - 1)
        if i <= u.hp then
            gfx.fillRect(hx, 5, 9, 9)
        else
            gfx.drawRect(hx, 5, 9, 9)
        end
    end
end

local function pips(wins, x, dir)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.ROUNDS do
        local px = x + dir * 10 * (i - 1)
        if i <= wins then
            gfx.fillRect(px, 18, 6, 6)
        else
            gfx.drawRect(px, 18, 6, 6)
        end
    end
end

local function drawHud()
    whiteText("YOU", 8, 3)
    hearts(Game.you, 40, 1)
    pips(State.youWins, 40, 1)
    whiteText("FOE", 400 - 8 - 26, 3)
    hearts(Game.foe, 400 - 40 - 9, -1)
    pips(State.foeWins, 400 - 40 - 6, -1)
    -- wind gauge
    local w = State.wind
    local n = math.min(4, math.ceil(math.abs(w) / 1.6))
    local arrows = w > 0.5 and string.rep(">", n) or (w < -0.5 and string.rep("<", n) or "-")
    whiteTextCentered("wind " .. arrows, 3)
    if State.phase == "aim" or State.phase == "banner" then
        drawAim()
        local u = State.turn == "you" and Game.you or Game.foe
        whiteText("power", 90, 222)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(140, 226, 122, 8)
        gfx.fillRect(141, 227, math.floor(u.power * 120), 6)
    end
    if State.phase == "banner" then
        panel(140, 100, 120, 26)
        whiteTextCentered(State.banner, 105)
    end
end

local function drawTitle()
    titleImg = titleImg or bigText("LOB")
    panel(50, 48, 300, 130)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = titleImg.width * 3
    titleImg:drawScaled(math.floor((400 - w) / 2), 56, 3)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("artillery duel - mind the wind", 118)
    whiteTextCentered("crank aim / hold Ⓐ, release to fire", 136)
    whiteTextCentered("press Ⓐ to start", 156)
end

local function drawOver()
    local img
    if State.youWon then
        winImg = winImg or bigText("VICTORY")
        img = winImg
    else
        loseImg = loseImg or bigText("DEFEAT")
        img = loseImg
    end
    panel(78, 70, 244, 86)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    local w = img.width * 2
    img:drawScaled(math.floor((400 - w) / 2), 80, 2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    whiteTextCentered("rounds " .. State.youWins .. " - " .. State.foeWins, 116)
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
