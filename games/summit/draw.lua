-- Summit: drawing on the shared Kit scaffolding.

local gfx = playdate.graphics

Draw = {}

local function drawActor(e)
    Kit.shadow(e.x, e.y, 1.2, e.z)
    VoxModel.draw(e.model, e.x, e.y, e.z)
    Vox.occlude(e.x - 2, e.x + 2, e.y, e.z, e.z + 4)
    VoxModel.drawGhost(e.model, e.x, e.y, e.z)
end

function Draw.frame()
    Vox.drawBG()
    local list = {}
    if Game.player then
        list[#list + 1] = { y = Game.player.y, fn = drawActor, arg = Game.player }
    end
    for _, b in ipairs(Game.brutes) do
        list[#list + 1] = { y = b.y, fn = drawActor, arg = b }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
    if Kit.mode == "title" then
        Kit.title("SUMMIT", {
            "shove the brutes into the goo",
            "d-pad move / Ⓐ shove / Ⓑ jump terraces",
            "crank winds a spin - full meter, big blast",
            "BEST " .. Kit.best,
            "press Ⓐ to start",
        })
        return
    end
    if Kit.mode == "over" then
        Kit.over(State.reason or "IN THE GOO", {
            "round " .. State.round .. " / score " .. State.score,
            State.newBest and "NEW BEST" or ("BEST " .. Kit.best),
            "Ⓐ again",
        })
        return
    end
    local p = Game.player
    Kit.marker(p.x, p.y, p.z + 4, State.erodeIn)
    Kit.text("SCORE " .. State.score, 8, 3)
    Kit.centered("CRUMBLE " .. math.ceil(State.erodeIn) .. "s", 3)
    Kit.text("ROUND " .. State.round, 400 - 74, 3)
    Kit.text("spin", 220, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(256, 226, 102, 8)
    gfx.fillRect(257, 227, math.floor(p.charge * 100), 6)
    if p.charge >= 1 and math.floor(State.erodeIn * 4) % 2 == 0 then
        Kit.text("READY", 362, 222)
    end
    if Kit.modeT > 0 then
        Kit.panel(120, 100, 160, 26)
        Kit.centered(State.banner, 105)
    end
end
