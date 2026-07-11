-- Rubble: entry point. Voxatron-style destructible voxel arena on the
-- shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run({
    init = Game.init,
    extra = function(t)
        t.hp = State.hp
        t.score = State.score
        t.wave = State.wave
        t.mode = Kit.mode
        t.enemies = #Game.enemies
    end,
    shotPath = "build/rubble-shot.png",
})
