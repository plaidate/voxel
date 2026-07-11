-- Vault: drawing on the shared Kit scaffolding.

local gfx = playdate.graphics

Draw = {}

local function drawPlayer()
    local p = Game.player
    if p.inv > 0 and math.floor(p.inv * 15) % 2 == 0 then return end
    Kit.shadow(p.x, p.y, 1.2, p.z)
    VoxModel.draw(Game.playerModel, p.x, p.y, p.z)
    local ca, sa = math.cos(p.az), math.sin(p.az)
    if (p.swingT or 0) > 0 then
        -- sword flash arc
        for i = -1, 1 do
            local a = p.az + i * 0.5
            Vox.drawBlock(p.x + math.cos(a) * 2.5 - 0.5, p.y + math.sin(a) * 2.5,
                p.z + 1.5, 4)
        end
    else
        Vox.drawBlock(p.x + ca * 2 - 0.5, p.y + sa * 2, p.z + 1.5, 1)
    end
    Vox.occlude(p.x - 3, p.x + 3, p.y, p.z, p.z + 4)
    -- walls occlude: keep a see-through silhouette behind them
    VoxModel.drawGhost(Game.playerModel, p.x, p.y, p.z)
end

local function drawGrub(g)
    Kit.shadow(g.x, g.y, 1, g.z)
    VoxModel.draw(Game.grubModel, g.x, g.y, g.z)
    Vox.occlude(g.x - 1.5, g.x + 1.5, g.y, g.z, g.z + 2)
    VoxModel.drawGhost(Game.grubModel, g.x, g.y, g.z)
end

local function drawItem(it)
    local z = 1 + (math.sin(playdate.getCurrentTimeMilliseconds() / 250) + 1) * 0.4
    local m = it.kind == "heart" and 4 or (it.kind == "key" and 4 or 1)
    Vox.drawBlock(it.x - 0.5, it.y, z, m)
    if it.kind == "key" then
        Vox.drawBlock(it.x - 0.5, it.y, z + 1, 4)
    end
    Vox.occlude(it.x - 1, it.x + 1, it.y, 1, 3)
end

local function drawBomb(b)
    local m = (math.floor(b.t * 8) % 2 == 0) and 1 or 4
    Vox.drawBlock(b.x - 0.5, b.y, b.z + 0.5, m)
    Vox.occlude(b.x - 1, b.x + 1, b.y, b.z, b.z + 1)
end

function Draw.frame()
    Vox.drawBG()
    local list = {}
    if Game.player then
        list[#list + 1] = { y = Game.player.y, fn = drawPlayer }
    end
    for _, g in ipairs(Game.grubs) do
        list[#list + 1] = { y = g.y, fn = drawGrub, arg = g }
    end
    for _, it in ipairs(Game.items) do
        list[#list + 1] = { y = it.y, fn = drawItem, arg = it }
    end
    for _, b in ipairs(Game.bombs) do
        list[#list + 1] = { y = b.y, fn = drawBomb, arg = b }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
    if Kit.mode == "title" then
        Kit.title("VAULT", {
            "find the idol - five rooms down",
            "d-pad move / crank aim / Ⓐ sword+leap / Ⓑ bomb",
            "keys open doors; bombs open anything",
            "press Ⓐ to start" ..
                (playdate.datastore.read("save") and "  /  Ⓑ continue" or ""),
        })
        return
    end
    if Kit.mode == "over" then
        Kit.over(State.reason, {
            State.won and "the vault is yours" or ("room " .. State.room),
            "Ⓐ again",
        })
        return
    end
    local p = Game.player
    Kit.marker(p.x, p.y, p.z + 4, playdate.getCurrentTimeMilliseconds() / 1000)
    Kit.text("ROOM " .. State.room, 8, 3)
    Kit.centered("KEYS " .. State.keys .. "   BOMBS " .. State.bombs, 3)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MAX_HP do
        local x = 400 - 12 * i
        if i <= State.hp then
            gfx.fillRect(x, 5, 8, 8)
        else
            gfx.drawRect(x, 5, 8, 8)
        end
    end
    if Kit.modeT > 0 then
        Kit.panel(120, 100, 160, 26)
        Kit.centered(State.banner, 105)
    end
end
