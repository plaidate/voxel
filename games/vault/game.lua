-- Vault: a five-room dungeon crawl where the dungeon is made of real
-- voxels — locked doors want keys, but any wall falls to a bomb. Crank
-- aims the sword; ledges and parapets are jumpable; goo burns. Session
-- state persists per room and mirrors to the datastore for continues.

-- sparse dungeon: bare D-minor tolls with long silences, a lone answer
local TRACK = {
    bpm = 66,
    bass = { 38, 0, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 36, 0 },
    lead = { 0, 0, 0, 0, 0, 0, 62, 0, 0, 0, 0, 0, 0, 0, 65, 0 },
    hat  = { 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
}

local GOO = 1

Game = {
    player = nil,
    grubs = {},
    items = {},
    bombs = {},
    pots = {},
    parts = {},
    def = nil,
}

Game.playerModel = VoxModel.fromLayers({
    { "4.4", "4.4" },
    { "444", "444" },
    { "444", "444" },
    { ".4.", ".4." },
})

Game.grubModel = VoxModel.fromLayers({
    { "11", "11", "11" },
    { "..", "..", "44" },
})

local OPEN0, OPEN1 = 44, 51 -- n/s opening span (x); e/w uses y 28..35
local DOORS = {
    n = { x0 = OPEN0, x1 = OPEN1, y0 = 0, y1 = 1 },
    s = { x0 = OPEN0, x1 = OPEN1, y0 = Vox.D - 2, y1 = Vox.D - 1 },
    w = { x0 = 0, x1 = 1, y0 = 28, y1 = 35 },
    e = { x0 = Vox.W - 2, x1 = Vox.W - 1, y0 = 28, y1 = 35 },
}

local function roomState(id)
    local rs = State.session.rooms[id]
    if not rs then
        rs = { pots = {}, grubs = {}, doors = {}, key = false, bomb = false }
        State.session.rooms[id] = rs
    end
    return rs
end

-- Room-state sets (rs.grubs / rs.pots) are keyed by STRING indices:
-- datastore JSON turns sparse integer keys into strings (and contiguous
-- ones into arrays), so integer-keyed writes silently vanished on
-- continue, resurrecting killed grubs and smashed pots. Write string
-- keys; read both forms so old saves still count.
local function rsMark(set, i)
    set[tostring(i)] = true
end

local function rsHas(set, i)
    return set[tostring(i)] or set[i] or false
end

function Game.buildRoom(id)
    local def = Rooms[id]
    Game.def = def
    local rs = roomState(id)
    Vox.clear()
    Vox.floorGrid(2, 3, 8, 0)
    -- goo pools (dark floor)
    for _, g in ipairs(def.goo or {}) do
        for x = g[1] - g[3], g[1] + g[3] do
            for y = g[2] - g[3], g[2] + g[3] do
                if (x - g[1]) ^ 2 + (y - g[2]) ^ 2 <= g[3] * g[3]
                    and x > 2 and x < Vox.W - 3 and y > 2 and y < Vox.D - 3 then
                    Vox.set(x, y, 0, GOO)
                end
            end
        end
    end
    -- border walls with openings on exit sides
    for x = 0, Vox.W - 1 do
        for y = 0, Vox.D - 1 do
            if x < 2 or x >= Vox.W - 2 or y < 2 or y >= Vox.D - 2 then
                local inOpen = false
                for side in pairs(def.exits or {}) do
                    if (side == "n" and y < 2 and x >= OPEN0 and x <= OPEN1)
                        or (side == "s" and y >= Vox.D - 2 and x >= OPEN0 and x <= OPEN1)
                        or (side == "w" and x < 2 and y >= 28 and y <= 35)
                        or (side == "e" and x >= Vox.W - 2 and y >= 28 and y <= 35) then
                        inOpen = true
                    end
                end
                if not inOpen then
                    Vox.column(x, y, 4, 2)
                end
            end
        end
    end
    -- locked doors: white columns filling the opening
    for side, locked in pairs(def.locked or {}) do
        if locked and not rs.doors[side] then
            local d = DOORS[side]
            for x = d.x0, d.x1 do
                for y = d.y0, d.y1 do
                    Vox.column(x, y, 3, 4, 4)
                end
            end
        end
    end
    -- interior walls / ledges
    for _, w in ipairs(def.walls or {}) do
        for x = w[1], w[3] do
            for y = w[2], w[4] do
                Vox.column(x, y, w[5], 2)
            end
        end
    end
    -- pots are little voxel columns; runtime list tracks the live ones
    Game.pots = {}
    for i, pt in ipairs(def.pots or {}) do
        if not rsHas(rs.pots, i) then
            Vox.column(pt[1], pt[2], 2, 2)
            Game.pots[#Game.pots + 1] = { i = i, x = pt[1], y = pt[2] }
        end
    end
    -- the idol
    if def.idol then
        for dx = 0, 1 do
            for dy = 0, 1 do
                for z = 3, 5 do Vox.set(def.idol[1] + dx, def.idol[2] + dy, z, 4) end
            end
        end
    end
    Vox.buildBG()
    -- actors and items
    Game.grubs = {}
    for i, g in ipairs(def.grubs or {}) do
        if not rsHas(rs.grubs, i) then
            Game.grubs[#Game.grubs + 1] = {
                i = i, x = g[1] + 0.5, y = g[2] + 0.5,
                z = Vox.heightAt(g[1], g[2]), vz = 0, hw = 1, grounded = true,
            }
        end
    end
    Game.items = {}
    if def.key and not rs.key then
        Game.items[#Game.items + 1] = { kind = "key", x = def.key[1], y = def.key[2] }
    end
    if def.bomb and not rs.bomb then
        Game.items[#Game.items + 1] = { kind = "bomb", x = def.bomb[1], y = def.bomb[2] }
    end
    Game.bombs = {}
    Game.parts = {}
end

local ENTRY = {
    n = { 48, 5 }, s = { 48, Vox.D - 6 },
    w = { 5, 32 }, e = { Vox.W - 6, 32 },
}

function Game.enterRoom(id, fromSide)
    State.room = id
    State.session.visited[id] = true
    Game.buildRoom(id)
    local at = fromSide and ENTRY[fromSide] or { 48, Vox.D - 10 }
    Game.player = Game.player or {}
    local p = Game.player
    p.x, p.y = at[1] + 0.5, at[2] + 0.5
    p.z = Vox.heightAt(at[1], at[2])
    p.vz, p.hw, p.grounded = 0, 1.1, true
    p.az = p.az or -math.pi / 2
    p.cd, p.inv = 0, p.inv or 0
    p.kbx, p.kby = 0, 0
    Kit.setMode("play", Config.BANNER_T)
    State.banner = "ROOM " .. id
    Harness.count("rooms")
    playdate.datastore.write({
        room = id, hp = State.hp, keys = State.keys, bombs = State.bombs,
        session = State.session,
    }, "save")
end

function Game.startGame(continue)
    if continue then
        local sav = playdate.datastore.read("save")
        if sav then
            State.reset()
            State.hp, State.keys, State.bombs = sav.hp, sav.keys, sav.bombs
            State.session = sav.session
            Game.enterRoom(sav.room, nil)
            return
        end
    end
    State.reset()
    Game.enterRoom("A", nil)
end

function Game.init()
    Music.set(TRACK)
    Game.startGame()
    Kit.setMode("title")
end

local function gameOver(reason, won)
    Kit.setMode("over", 1.2)
    State.reason = reason
    State.won = won or false
    if won then
        playdate.datastore.delete("save")
        Harness.count("wins")
    else
        Harness.count("gameovers")
    end
end

local function hurt(kx, ky)
    local p = Game.player
    if p.inv > 0 then return end
    p.inv = Config.IFRAMES
    State.hp = State.hp - 1
    p.kbx, p.kby = kx * 24, ky * 24
    Snd.play("saw", 90, 0.25, 0.5)
    Harness.count("hurt")
    if State.hp <= 0 then gameOver("SLAIN") end
end

local function gooAt(x, y)
    local h, m = Vox.surfaceAt(math.floor(x), math.floor(y))
    return h == 1 and m == GOO
end

local function smashPot(idx)
    local pt = Game.pots[idx]
    rsMark(roomState(State.room).pots, pt.i)
    Vox.set(pt.x, pt.y, 1, nil)
    Vox.set(pt.x, pt.y, 2, nil)
    Vox.repaint(pt.x - 1, pt.x + 1)
    Snd.play("noise", 160, 0.1, 0.4)
    for _ = 1, 4 do Kit.spawnPart(Game.parts, pt.x, pt.y, 2, 3) end
    local r = math.random()
    if r < 0.3 then
        Game.items[#Game.items + 1] = { kind = "heart", x = pt.x, y = pt.y }
    elseif r < 0.5 then
        Game.items[#Game.items + 1] = { kind = "bomb", x = pt.x, y = pt.y }
    end
    table.remove(Game.pots, idx)
    Harness.count("pots")
end

local function swing()
    local p = Game.player
    if p.cd > 0 then return end
    p.cd = Config.SWORD_CD
    p.swingT = 0.15
    Snd.play("square", 700, 0.05, 0.25)
    local fa, fs = math.cos(p.az), math.sin(p.az)
    for i = #Game.grubs, 1, -1 do
        local g = Game.grubs[i]
        local dx, dy = g.x - p.x, g.y - p.y
        if dx * dx + dy * dy < Config.SWORD_R ^ 2 and dx * fa + dy * fs > 0 then
            rsMark(roomState(State.room).grubs, g.i)
            for _ = 1, 5 do Kit.spawnPart(Game.parts, g.x, g.y, g.z + 1, 1) end
            table.remove(Game.grubs, i)
            Harness.count("kills")
        end
    end
    for i = #Game.pots, 1, -1 do
        local pt = Game.pots[i]
        local dx, dy = pt.x - p.x, pt.y - p.y
        if dx * dx + dy * dy < Config.SWORD_R ^ 2 then smashPot(i) end
    end
end

-- is a locked door's opening passable now (three consecutive positions
-- along the span cleared through both wall rows, z 1..3)?
local function doorBlasted(side)
    local d = DOORS[side]
    local horiz = side == "n" or side == "s"
    local a0, a1 = d.x0, d.x1
    local b0, b1 = d.y0, d.y1
    if not horiz then a0, a1, b0, b1 = d.y0, d.y1, d.x0, d.x1 end
    local run = 0
    for a = a0, a1 do
        local clear = true
        for b = b0, b1 do
            local x, y = a, b
            if not horiz then x, y = b, a end
            for z = 1, 3 do
                if Vox.get(x, y, z) then clear = false end
            end
        end
        run = clear and run + 1 or 0
        if run >= 3 then return true end
    end
    return false
end

local function explode(b)
    local removed = Vox.carve(b.x, b.y, b.z + 1, Config.BOMB_R)
    Kit.burst(Game.parts, removed, 8)
    Snd.play("noise", 70, 0.3, 0.5)
    Harness.count("bombsused")
    local p = Game.player
    if (p.x - b.x) ^ 2 + (p.y - b.y) ^ 2 < 16 then
        hurt((p.x - b.x) * 0.1, (p.y - b.y) * 0.1)
    end
    for i = #Game.grubs, 1, -1 do
        local g = Game.grubs[i]
        if (g.x - b.x) ^ 2 + (g.y - b.y) ^ 2 < 20 then
            rsMark(roomState(State.room).grubs, g.i)
            table.remove(Game.grubs, i)
            Harness.count("kills")
        end
    end
    for i = #Game.pots, 1, -1 do
        local pt = Game.pots[i]
        if (pt.x - b.x) ^ 2 + (pt.y - b.y) ^ 2 < 14 then smashPot(i) end
    end
    -- a bombed-open locked door must stay open on re-entry: persist it
    -- to the room state, exactly like a key unlock
    local rs = roomState(State.room)
    for side, locked in pairs(Game.def.locked or {}) do
        if locked and not rs.doors[side] and doorBlasted(side) then
            rs.doors[side] = true
            Harness.count("doors")
        end
    end
end

-- unlock a locked door when standing near it with a key
local function tryDoors()
    local p = Game.player
    local def = Game.def
    local rs = roomState(State.room)
    for side, locked in pairs(def.locked or {}) do
        if locked and not rs.doors[side] and State.keys > 0 then
            local d = DOORS[side]
            local cx = (d.x0 + d.x1) / 2
            local cy = (d.y0 + d.y1) / 2
            if (p.x - cx) ^ 2 + (p.y - cy) ^ 2 < 36 then
                State.keys = State.keys - 1
                rs.doors[side] = true
                for x = d.x0, d.x1 do
                    for y = d.y0, d.y1 do
                        for z = 1, 3 do Vox.set(x, y, z, nil) end
                    end
                end
                Vox.repaint(d.x0 - 1, d.x1 + 1)
                Snd.play("tri", 523, 0.12, 0.3)
                Harness.count("doors")
            end
        end
    end
end

local SIDE_OPP = { n = "s", s = "n", w = "e", e = "w" }

local function checkTransition()
    local p = Game.player
    local side
    if p.y < 1.2 then side = "n"
    elseif p.y > Vox.D - 2.2 then side = "s"
    elseif p.x < 1.2 then side = "w"
    elseif p.x > Vox.W - 2.2 then side = "e" end
    if not side then return end
    local nxt = Game.def.exits and Game.def.exits[side]
    if nxt then
        Game.enterRoom(nxt, SIDE_OPP[side])
    else
        -- bombed through the outer wall of the dungeon: nothing out there
        p.x = Util.clamp(p.x, 2.5, Vox.W - 3.5)
        p.y = Util.clamp(p.y, 2.5, Vox.D - 3.5)
    end
end

local apT, apStuck, apLX, apLY = 0, 0, 0, 0
local apWanderT, apWX, apWY = 0, 0, 0
local function autoplay(dt, inp)
    local p = Game.player
    -- objective: item > pot > grub > best exit
    local tx, ty
    local best = math.huge
    for _, it in ipairs(Game.items) do
        local d = (it.x - p.x) ^ 2 + (it.y - p.y) ^ 2
        if d < best then best, tx, ty = d, it.x, it.y end
    end
    if not tx then
        for _, pt in ipairs(Game.pots) do
            local d = (pt.x - p.x) ^ 2 + (pt.y - p.y) ^ 2
            if d < best then best, tx, ty = d, pt.x, pt.y end
        end
    end
    if not tx and Game.def.idol then
        tx, ty = Game.def.idol[1], Game.def.idol[2]
    end
    if not tx then
        -- pick an exit deterministically: a locked door we hold a key
        -- for beats unvisited beats anything
        local pick
        for _, side in ipairs({ "n", "e", "s", "w" }) do
            local id = Game.def.exits and Game.def.exits[side]
            if id then
                local locked = Game.def.locked and Game.def.locked[side]
                    and not roomState(State.room).doors[side]
                if locked and State.keys > 0 then
                    pick = side
                    break
                end
                if not State.session.visited[id] and not locked and not pick then
                    pick = side
                end
            end
        end
        if not pick then
            for _, side in ipairs({ "n", "e", "s", "w" }) do
                if Game.def.exits and Game.def.exits[side] then
                    pick = side
                    break
                end
            end
        end
        if pick then
            local d = DOORS[pick]
            tx, ty = (d.x0 + d.x1) / 2, (d.y0 + d.y1) / 2
        end
    end
    if not tx then return end
    -- boxed in: wander randomly for a while instead of grinding the wall
    if apWanderT > 0 then
        apWanderT = apWanderT - dt
        tx, ty = p.x + apWX, p.y + apWY
    end
    local dx, dy = tx - p.x, ty - p.y
    inp.aim = math.atan(dy, dx)
    inp.mx = (dx > 1 and 1) or (dx < -1 and -1) or 0
    inp.my = (dy > 1 and 1) or (dy < -1 and -1) or 0
    -- swing at anything close
    apT = apT - dt
    if apT <= 0 then
        apT = 0.5
        for _, g in ipairs(Game.grubs) do
            if (g.x - p.x) ^ 2 + (g.y - p.y) ^ 2 < 9 then inp.swing = true end
        end
        for _, pt in ipairs(Game.pots) do
            if (pt.x - p.x) ^ 2 + (pt.y - p.y) ^ 2 < 9 then inp.swing = true end
        end
    end
    -- stuck: jump, then bomb
    if math.abs(p.x - apLX) + math.abs(p.y - apLY) < 0.05 then
        apStuck = apStuck + dt
    else
        apStuck = 0
    end
    apLX, apLY = p.x, p.y
    if apStuck > 1 then inp.jump = true end
    if apStuck > 3 and State.bombs > 0 and State.hp > 2 and #Game.bombs == 0 then
        inp.bomb = true
        apStuck = 0
    elseif apStuck > 4 then
        local a = math.random() * math.pi * 2
        apWX, apWY = math.cos(a) * 20, math.sin(a) * 20
        apWanderT = 2
        apStuck = 0
    end
end

function Game.update(dt)
    Music.update(dt)
    local inp = Input.state
    if Kit.mode == "title" then
        if inp.confirm then Game.startGame() end
        if inp.bomb then Game.startGame(true) end
        return
    end
    if Kit.mode == "over" then
        Kit.updateParts(Game.parts, dt)
        if Kit.modeT <= 0 and inp.confirm then Game.startGame() end
        return
    end
    Kit.updateParts(Game.parts, dt)
    if Kit.modeT > 0 then return end -- room banner
    inp.jump = inp.jump or false
    if Harness.enabled then autoplay(dt, inp) end
    local p = Game.player
    p.cd = math.max(0, p.cd - dt)
    p.inv = math.max(0, p.inv - dt)
    p.swingT = math.max(0, (p.swingT or 0) - dt)
    if inp.aim then p.az = inp.aim end
    local dx, dy = inp.mx, inp.my
    if dx ~= 0 and dy ~= 0 then dx, dy = dx * 0.7071, dy * 0.7071 end
    local vx = dx * Config.SPEED + p.kbx
    local vy = dy * Config.SPEED + p.kby
    p.kbx, p.kby = p.kbx * 0.85, p.kby * 0.85
    VoxPhys.tryMove(p, p.x + vx * dt, p.y)
    VoxPhys.tryMove(p, p.x, p.y + vy * dt)
    if inp.jump and p.grounded then
        p.vz = Config.JUMP_VEL
        p.grounded = false
    end
    VoxPhys.physZ(p, dt, Config.GRAVITY)
    if inp.swing then swing() end
    if inp.bomb and State.bombs > 0 then
        State.bombs = State.bombs - 1
        Game.bombs[#Game.bombs + 1] = { x = p.x, y = p.y, z = p.z, t = 1.5 }
    end
    for i = #Game.bombs, 1, -1 do
        local b = Game.bombs[i]
        b.t = b.t - dt
        if b.t <= 0 then
            explode(b)
            table.remove(Game.bombs, i)
        end
    end
    if Kit.mode ~= "play" then return end
    -- goo burns
    if p.grounded and gooAt(p.x, p.y) then
        hurt(-vx * 0.06, -vy * 0.06)
        if Kit.mode ~= "play" then return end
    end
    -- grubs
    for _, g in ipairs(Game.grubs) do
        local gx, gy = p.x - g.x, p.y - g.y
        local d = math.sqrt(gx * gx + gy * gy)
        if d < Config.AGGRO_R and d > 0.01 then
            local mx, my = gx / d, gy / d
            local nx, ny = g.x + mx * Config.GRUB_SPEED * dt, g.y + my * Config.GRUB_SPEED * dt
            if not gooAt(nx, g.y) then VoxPhys.tryMove(g, nx, g.y) end
            if not gooAt(g.x, ny) then VoxPhys.tryMove(g, g.x, ny) end
        end
        VoxPhys.physZ(g, dt, Config.GRAVITY)
        if d < 2.2 and math.abs(g.z - p.z) < 2 then
            hurt(gx / d, gy / d)
            if Kit.mode ~= "play" then return end
        end
    end
    -- items
    for i = #Game.items, 1, -1 do
        local it = Game.items[i]
        if (it.x - p.x) ^ 2 + (it.y - p.y) ^ 2 < 4 then
            Snd.play("square", 1047, 0.07, 0.3)
            if it.kind == "key" then
                State.keys = State.keys + 1
                roomState(State.room).key = true
                Harness.count("keysgot")
            elseif it.kind == "bomb" then
                State.bombs = State.bombs + 1
                if Game.def.bomb and it.x == Game.def.bomb[1] then
                    roomState(State.room).bomb = true
                end
            else
                State.hp = math.min(Config.MAX_HP, State.hp + 1)
            end
            table.remove(Game.items, i)
        end
    end
    tryDoors()
    -- the idol
    if Game.def.idol then
        local ix, iy = Game.def.idol[1] + 1, Game.def.idol[2] + 1
        if (p.x - ix) ^ 2 + (p.y - iy) ^ 2 < 12 then
            Snd.play("tri", 784, 0.2, 0.4)
            gameOver("VICTORY", true)
            return
        end
    end
    checkTransition()
end
