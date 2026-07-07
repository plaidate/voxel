-- Lob: drawing. Scene pattern shared with the other games, plus per-side
-- HUD (hearts + round pips), a wind gauge, aim dots for whichever mortar
-- is aiming, and the power meter. Panels/text/shadows come from Kit.

local gfx = playdate.graphics

Draw = {}

local function drawUnit(u)
    if u.flash > 0 and math.floor(u.flash * 15) % 2 == 0 then
        return
    end
    Kit.shadow(u.x, u.y, 1.2)
    VoxModel.draw(u.model, u.x, u.y, u.z)
    Vox.occlude(u.x - 2, u.x + 2, u.y, u.z, u.z + 4)
end

local function drawShot(s)
    Vox.drawBlock(s.x - 0.5, s.y, s.z, 4)
    Vox.occlude(s.x - 1, s.x + 1, s.y, s.z, s.z + 1)
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
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
end

-- aim dots for whichever mortar is choosing its shot
local function drawAim(u)
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
    Kit.text("YOU", 8, 3)
    hearts(Game.you, 40, 1)
    pips(State.youWins, 40, 1)
    Kit.text("FOE", 400 - 8 - 26, 3)
    hearts(Game.foe, 400 - 40 - 9, -1)
    pips(State.foeWins, 400 - 40 - 6, -1)
    -- wind gauge
    local w = State.wind
    local n = math.min(4, math.ceil(math.abs(w) / 1.6))
    local arrows = w > 0.5 and string.rep(">", n) or (w < -0.5 and string.rep("<", n) or "-")
    Kit.centered("wind " .. arrows, 3)
    if State.phase == "aim" or State.phase == "banner" then
        local u = State.turn == "you" and Game.you or Game.foe
        drawAim(u)
        Kit.text("power", 90, 222)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(140, 226, 122, 8)
        gfx.fillRect(141, 227, math.floor(u.power * 120), 6)
    end
    if State.phase == "banner" then
        Kit.panel(140, 100, 120, 26)
        Kit.centered(State.banner, 105)
    end
end

local function drawTitle()
    Kit.panel(50, 48, 300, 130)
    Kit.bigCentered("LOB", 56, 3)
    Kit.centered("artillery duel - mind the wind", 118)
    Kit.centered("crank aim / hold Ⓐ, release to fire", 136)
    Kit.centered("press Ⓐ to start", 156)
end

local function drawOver()
    Kit.panel(78, 70, 244, 86)
    Kit.bigCentered(State.youWon and "VICTORY" or "DEFEAT", 80, 2)
    Kit.centered("rounds " .. State.youWins .. " - " .. State.foeWins, 116)
    Kit.centered("Ⓐ again", 134)
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
