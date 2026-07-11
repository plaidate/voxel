-- Herd: entry point. Pocket Lemmings on the shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run{
    init = Game.init,
    extra = function(t)
        t.level = State.level
        t.home = State.saved
        t.lost = State.dead
        t.alive = #Game.crits
        t.blasts = State.blasts
        t.mode = Kit.mode
    end,
    shotPath = "build/herd-shot.png",
}
