-- Bulwark: drawing. Scene pattern shared with the other games, plus the
-- build-phase piece ghost, the keep cannon with aim dots, phase timer,
-- and keep hearts.

local gfx = playdate.graphics

Draw = {}

local function drawCat(c)
    Kit.shadow(c.x, c.y, 1.4)
    VoxModel.draw(Game.catModel, c.x, c.y, c.z)
    Vox.occlude(c.x - 2, c.x + 2, c.y, c.z, c.z + 3)
end

local function drawShell(s)
    Vox.drawBlock(s.x - 0.5, s.y, s.z, 4)
    Vox.occlude(s.x - 1, s.x + 1, s.y, s.z, s.z + 1)
end

local function drawCannon()
    local can = Game.cannon
    local ca, sa = math.cos(can.az), math.sin(can.az)
    Vox.drawBlock(can.x + ca * 1.8 - 0.5, can.y + sa * 1.8, can.z, 1)
end

local function drawScene()
    Vox.drawBG()
    local list = {}
    for _, c in ipairs(Game.cats) do
        list[#list + 1] = { y = c.y, fn = drawCat, arg = c }
    end
    for _, s in ipairs(Game.shells) do
        list[#list + 1] = { y = s.y, fn = drawShell, arg = s }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    if Game.cannon then
        list[#list + 1] = { y = Game.cannon.y, fn = drawCannon }
    end
    Kit.drawSorted(list)
end

local function drawGhost()
    local ok = Game.canPlace(State.curX, State.curY)
    if not ok and math.floor(playdate.getCurrentTimeMilliseconds() / 120) % 2 == 0 then
        return
    end
    gfx.setColor(gfx.kColorWhite)
    for _, c in ipairs(Game.pieceCells()) do
        local px = (State.curX + c[1]) * 2
        local py = (State.curY + c[2]) * 2
        local sx = Vox.OX + px * Vox.S
        local sy = Vox.OY + py * Vox.TY - 2 * Vox.TZ
        gfx.drawRect(sx, sy, 2 * Vox.S, 2 * Vox.TY)
    end
end

local function drawReticle()
    local can = Game.cannon
    gfx.setColor(gfx.kColorWhite)
    local ca, sa = math.cos(can.az), math.sin(can.az)
    for i = 6, 15, 3 do
        local rx = math.floor(Vox.OX + (can.x + ca * i) * Vox.S + 0.5)
        local ry = math.floor(Vox.OY + (can.y + sa * i) * Vox.TY - can.z * Vox.TZ + 0.5)
        gfx.fillRect(rx, ry, 2, 2)
    end
end

local function drawHud()
    Kit.text("SCORE " .. State.score, 8, 3)
    Kit.text("ROUND " .. math.min(State.round + (State.phase == "siege" and 0 or 1), Config.ROUNDS)
        .. "/" .. Config.ROUNDS, 8, 222)
    -- keep hearts (blink while freshly hit)
    if State.keepFlash <= 0 or math.floor(State.keepFlash * 15) % 2 == 0 then
        gfx.setColor(gfx.kColorWhite)
        for i = 1, Config.KEEP_HP do
            local x = 400 - 12 * i
            if i <= State.keepHp then
                gfx.fillRect(x, 5, 8, 8)
            else
                gfx.drawRect(x, 5, 8, 8)
            end
        end
    end
    if State.phase == "build" then
        Kit.centered("BUILD " .. math.ceil(State.phaseT) .. "s", 3)
        drawGhost()
        Kit.text("d-pad move / crank turn / Ⓐ place", 110, 224)
    elseif State.phase == "siege" then
        Kit.centered("SIEGE " .. math.ceil(State.phaseT) .. "s", 3)
        drawReticle()
        local can = Game.cannon
        Kit.text("power", 104, 222)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(140, 226, 122, 8)
        gfx.fillRect(141, 227, math.floor(can.power * 120), 6)
    elseif State.phase == "banner" then
        Kit.panel(120, 100, 160, 26)
        Kit.centered(State.banner, 105)
    end
end

local function drawTitle()
    Kit.panel(46, 42, 308, 146)
    Kit.bigCentered("BULWARK", 50, 3)
    Kit.centered("enclose the keep - survive the siege", 112)
    Kit.centered("build: d-pad move, crank turn, Ⓐ place", 130)
    Kit.centered("siege: crank aim, hold Ⓐ, release to fire", 146)
    Kit.centered("press Ⓐ to start", 166)
end

local function drawOver()
    Kit.panel(78, 70, 244, 86)
    Kit.bigCentered(State.reason, 80, 2)
    Kit.centered("score " .. State.score, 116)
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
