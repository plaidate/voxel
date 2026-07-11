-- Summit: entry point. Terrace sumo on the shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run{
    init = Game.init,
    extra = function(t)
        t.round = State.round
        t.brutes = #Game.brutes
        t.score = State.score
        t.mode = Kit.mode
    end,
    shotPath = "build/summit-shot.png",
}
