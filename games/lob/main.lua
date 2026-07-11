-- Lob: entry point. Turn-based artillery on the shared Vox engine.

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
        t.turn = State.turn
        t.hpYou = Game.you and Game.you.hp or 0
        t.hpFoe = Game.foe and Game.foe.hp or 0
        t.youWins = State.youWins
        t.foeWins = State.foeWins
        t.mode = Kit.mode
    end,
    shotPath = "build/lob-shot.png",
})
