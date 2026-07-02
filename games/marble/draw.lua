-- Marble: drawing on the shared Kit scaffolding.

local gfx = playdate.graphics

Draw = {}

local function drawBall()
    local b = Game.ball
    Kit.shadow(b.x, b.y, 1)
    VoxModel.draw(Game.ballModel, b.x, b.y, b.z)
    Vox.occlude(b.x - 1.5, b.x + 1.5, b.y, b.z, b.z + 2)
end

function Draw.frame()
    Vox.drawBG()
    local list = {}
    if Game.ball then
        list[#list + 1] = { y = Game.ball.y, fn = drawBall }
    end
    for _, q in ipairs(Game.parts) do
        list[#list + 1] = { y = q.y, fn = Kit.drawPart, arg = q }
    end
    Kit.drawSorted(list)
    if State.mode == "title" then
        Kit.title("MARBLE", {
            "roll west pad to the white east pad",
            "d-pad steer / crank winds boost / Ⓐ burst",
            "goo eats marbles - crests catch air",
            "press Ⓐ to start",
        })
        return
    end
    if State.mode == "over" then
        Kit.over(State.reason, {
            "course " .. State.course .. " / score " .. State.score,
            "Ⓐ again",
        })
        return
    end
    local b = Game.ball
    Kit.marker(b.x, b.y, b.z + 2, State.timer)
    Kit.text("SCORE " .. State.score, 8, 3)
    Kit.centered("TIME " .. math.max(0, math.ceil(State.timer)) .. "s", 3)
    gfx.setColor(gfx.kColorWhite)
    for i = 1, Config.MARBLES do
        local x = 400 - 12 * i
        if i <= State.marbles then
            gfx.fillRect(x, 5, 8, 8)
        else
            gfx.drawRect(x, 5, 8, 8)
        end
    end
    Kit.text("COURSE " .. State.course, 8, 222)
    Kit.text("boost", 220, 222)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(262, 226, 96, 8)
    gfx.fillRect(263, 227, math.floor(b.charge * 94), 6)
    if State.phase == "banner" then
        Kit.panel(120, 100, 160, 26)
        Kit.centered(State.banner, 105)
    end
end
