-- Excavate: entry point. Volumetric digging on the shared Vox engine.

import "lib"
import "config"
import "gamestate"
import "game"
import "input"
import "draw"

Kit.run({
    init = Game.init,
    shotPath = "build/excavate-shot.png",
    extra = function(t)
        t.level = State.level
        t.hp = State.hp
        t.left = State.left
        t.score = State.score
        t.mode = Kit.mode
    end,
})
