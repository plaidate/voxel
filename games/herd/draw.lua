-- Herd: drawing. Scene pattern shared with the other games, plus the dig
-- cursor, the release-rate dial and the flock tally.

local gfx = playdate.graphics

Draw = {}

local function drawSheep(c)
    Kit.shadow(c.x, c.y, 1, c.z)
    VoxModel.draw(Game.sheepModel, c.x, c.y, c.z)
    Vox.occlude(c.x - 1.5, c.x + 1.5, c.y, c.z, c.z + 2)
    VoxModel.drawGhost(Game.sheepModel, c.x, c.y, c.z)
end

local function drawScene()
    Vox.drawBG()
    local list = {}
    for _, c in ipairs(Game.crits) do
        list[#list + 1] = { y = c.y, fn = drawSheep, arg = c }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
end

local function drawCursor()
    local g = Vox.heightAt(State.curX, State.curY)
    local sx = Vox.OX + (State.curX - 2) * Vox.S
    local sy = Vox.OY + State.curY * Vox.TY - g * Vox.TZ - 2 * Vox.TY
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(sx, sy, 5 * Vox.S, 5 * Vox.TY)
end

local function drawHud()
    Kit.text("HOME " .. State.saved .. "/" .. State.quota .. "   LOST " .. State.dead, 8, 3)
    Kit.centered("TIME " .. math.max(0, math.ceil(State.timer)) .. "s", 3)
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
    Kit.text("LEVEL " .. State.level .. "  SCORE " .. State.score, 8, 222)
    -- release-rate dial
    Kit.text("rate", 220, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(256, 226, 102, 8)
    local f = (State.rate - Config.RATE_MIN) / (Config.RATE_MAX - Config.RATE_MIN)
    gfx.fillRect(257, 227, math.floor(f * 100), 6)
    if Kit.modeT <= 0 and not Harness.enabled then
        drawCursor()
    end
    if Kit.modeT > 0 then
        Kit.panel(110, 100, 180, 26)
        Kit.centered(State.banner, 105)
    end
end

-- custom title layout (predates Kit.title's spacing; kept pixel-identical)
local function drawTitle()
    Kit.panel(46, 42, 308, 162)
    Kit.bigCentered("HERD", 50, 3)
    Kit.centered("dig and blast a path - get the flock home", 112)
    Kit.centered("d-pad cursor / Ⓐ dig / Ⓑ blast", 130)
    Kit.centered("crank sets the release rate", 146)
    Kit.centered("BEST " .. Kit.best, 164)
    Kit.centered("press Ⓐ to start", 182)
end

function Draw.frame()
    drawScene()
    if Kit.mode == "title" then
        drawTitle()
    elseif Kit.mode == "over" then
        Kit.over("FLOCK LOST", {
            "level " .. State.level .. " / score " .. State.score,
            State.newBest and "NEW BEST" or ("BEST " .. Kit.best),
            "Ⓐ again",
        })
    else
        drawHud()
    end
end
