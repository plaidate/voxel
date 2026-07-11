-- Voxelspace: entry point. Comanche-style heightmap flyover demo.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run({
    init = function()
        Game.init()
        -- the demo earns the Playdate's max refresh: override Kit.run's 30
        playdate.display.setRefreshRate(SMOKE_BUILD and 0 or Config.FPS)
    end,
    shotPath = "/Users/sdwfrost/Projects/playdate/voxel/build/voxelspace-shot.png",
    extra = function(t)
        t.mode = Kit.mode
        t.alt = math.floor(State.alt)
        t.segs = Draw.segs
    end,
})
