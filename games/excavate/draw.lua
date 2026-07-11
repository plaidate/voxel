-- Excavate: drawing. The player is often legitimately hidden inside a
-- tunnel, so a blinking miner's-lamp dot always marks the spot.

local gfx = playdate.graphics

Draw = {}

local function drawPlayer()
    local p = Game.player
    if p.inv > 0 and math.floor(p.inv * 15) % 2 == 0 then return end
    Kit.shadow(p.x, p.y, 1.2, p.z)
    VoxModel.draw(Game.playerModel, p.x, p.y, p.z)
    local ca, sa = math.cos(p.az), math.sin(p.az)
    Vox.drawBlock(p.x + ca * 2 - 0.5, p.y + sa * 2, p.z + 1.5, 1)
    Vox.occlude(p.x - 2.5, p.x + 2.5, p.y, p.z, p.z + 4)
    -- tunneled miner: keep a see-through silhouette where rock covers him
    VoxModel.drawGhost(Game.playerModel, p.x, p.y, p.z)
end

function Draw.frame()
    Vox.drawBG()
    local list = {}
    if Game.player then
        list[#list + 1] = { y = Game.player.y, fn = drawPlayer }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
    if Kit.mode == "title" then
        Kit.title("EXCAVATE", {
            "fossils are buried in the mound",
            "d-pad move / crank aim / Ⓐ dig / Ⓑ hop",
            "unsupported rock falls - mind the roof",
            "BEST " .. Kit.best,
            "press Ⓐ to start",
        })
        return
    end
    if Kit.mode == "over" then
        Kit.over(State.reason, {
            "level " .. State.level .. " / score " .. State.score,
            "BEST " .. Kit.best,
            "Ⓐ again",
        })
        return
    end
    local p = Game.player
    -- locator chevron: always visible, even deep in a tunnel
    Kit.marker(p.x, p.y, p.z + 4, State.timer)
    -- aim dots
    gfx.setColor(gfx.kColorWhite)
    local ca, sa = math.cos(p.az), math.sin(p.az)
    for i = 4, 8, 2 do
        local rx = math.floor(Vox.OX + (p.x + ca * i) * Vox.S + 0.5)
        local ry = math.floor(Vox.OY + (p.y + sa * i) * Vox.TY - (p.z + 1.5) * Vox.TZ + 0.5)
        gfx.fillRect(rx, ry, 2, 2)
    end
    Kit.text("FOSSILS " .. (#Game.fossils - State.left) .. "/" .. #Game.fossils, 8, 3)
    Kit.centered("TIME " .. math.max(0, math.ceil(State.timer)) .. "s", 3)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MAX_HP do
        local x = 400 - 12 * i
        if i <= State.hp then
            gfx.fillRect(x, 5, 8, 8)
        else
            gfx.drawRect(x, 5, 8, 8)
        end
    end
    Kit.text("LEVEL " .. State.level .. "  SCORE " .. State.score, 8, 222)
    if Kit.modeT > 0 then
        Kit.panel(100, 100, 200, 26)
        Kit.centered(State.banner, 105)
    end
end
