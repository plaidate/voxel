-- Crumble: entry point. Height-survival on the shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run{
    init = Game.init,
    extra = function(t)
        t.hp = State.hp
        t.score = State.score
        t.slime = State.slimeLevel
        t.mode = Kit.mode
    end,
    shotPath = "build/crumble-shot.png",
}
