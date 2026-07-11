-- Bulwark: entry point. Rampart-style build-and-siege on the shared Vox
-- engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run({
    init = Game.init,
    extra = function(t)
        t.phase = State.phase
        t.round = State.round
        t.keepHp = State.keepHp
        t.score = State.score
        t.cats = #Game.cats
        t.mode = Kit.mode
    end,
    shotPath = "build/bulwark-shot.png",
})
