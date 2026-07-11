-- Marble: entry point. Heightfield ball physics on the shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run{
    init = Game.init,
    extra = function(t)
        t.course = State.course
        t.marbles = State.marbles
        t.score = State.score
        t.mode = Kit.mode
    end,
    shotPath = "build/marble-shot.png",
}
