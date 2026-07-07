-- Voxelspace: entry point. Comanche-style heightmap flyover demo.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

playdate.display.setRefreshRate(SMOKE_BUILD and 0 or Config.FPS)
math.randomseed(playdate.getSecondsSinceEpoch())

Game.init()

local updMs, drwMs = 0, 0

if Harness.enabled then
    Harness.extra = function(t)
        t.mode = State.mode
        t.alt = math.floor(State.alt)
        t.segs = Draw.segs
        t.updMs = math.floor(updMs * 10) / 10
        t.drwMs = math.floor(drwMs * 10) / 10
    end
    if playdate.simulator then
        Harness.shotPath = "/Users/sdwfrost/Projects/playdate/voxel/build/voxelspace-shot.png"
    end
end

local frame = 0

function playdate.update()
    frame = frame + 1
    Harness.frame(frame, function()
        Input.poll()
        playdate.resetElapsedTime()
        Game.update(Config.DT)
        Util.runPending(Config.DT)
        updMs = updMs * 0.95 + playdate.getElapsedTime() * 50
        playdate.resetElapsedTime()
        Draw.frame()
        drwMs = drwMs * 0.95 + playdate.getElapsedTime() * 50
    end)
end
