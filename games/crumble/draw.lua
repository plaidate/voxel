-- Crumble: drawing. Same scene pattern as Rubble (bg blit, painter-sorted
-- actors, Vox.occlude, ghost pass) plus Kit screen shake on slime rises
-- and a spring charge meter in the bottom margin.

local gfx = playdate.graphics

Draw = {}

local function drawPlayer()
    local p = Game.player
    if p.inv > 0 and math.floor(p.inv * 15) % 2 == 0 then
        return
    end
    Kit.shadow(p.x, p.y, 1.2, p.z)
    VoxModel.draw(Game.playerModel, p.x, p.y, p.z)
    Vox.occlude(p.x - 2, p.x + 2, p.y, p.z, p.z + 4)
    VoxModel.drawGhost(Game.playerModel, p.x, p.y, p.z)
end

local function drawGem(gm)
    local m = (math.sin(gm.phase * 8) > 0) and 4 or 3
    Vox.drawBlock(gm.x - 0.5, gm.y, gm.z, m)
    Vox.occlude(gm.x - 1, gm.x + 1, gm.y, gm.z, gm.z + 1)
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
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
end

local function drawHud()
    local pp = Game.player
    if pp then Kit.marker(pp.x, pp.y, pp.z + 4, State.t or 0) end
    Kit.text("SCORE " .. State.score, 8, 3)
    Kit.text("SLIME " .. State.slimeLevel, 176, 3)
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
    Kit.text("spring", 90, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(140, 226, 122, 8)
    gfx.fillRect(141, 227, math.floor(p.charge * 120), 6)
end

local function drawTitle()
    Kit.panel(50, 44, 300, 148)
    Kit.bigCentered("CRUMBLE", 52, 3)
    Kit.centered("the slime rises - stay high, grab gems", 114)
    Kit.centered("d-pad move / Ⓑ hop / crank + Ⓐ spring", 132)
    Kit.centered("BEST " .. Kit.best, 150)
    Kit.centered("press Ⓐ to start", 168)
end

local function drawDead()
    Kit.panel(78, 70, 244, 104)
    Kit.bigCentered("CONSUMED", 80, 2)
    Kit.centered("score " .. State.score .. " / slime " .. State.slimeLevel, 116)
    Kit.centered(State.newBest and "NEW BEST" or ("BEST " .. Kit.best), 134)
    Kit.centered("Ⓐ again", 152)
end

function Draw.frame()
    Kit.applyShake()
    drawScene()
    if Kit.mode == "title" then
        drawTitle()
    elseif Kit.mode == "dead" then
        drawDead()
        Kit.text("SCORE " .. State.score, 8, 3)
    else
        drawHud()
    end
    Kit.doneShake()
end
