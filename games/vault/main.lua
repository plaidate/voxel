-- Vault: entry point. The five-room dungeon crawl on the shared Vox
-- engine.

import "lib"
import "config"
import "gamestate"
import "rooms"
import "game"
import "input"
import "draw"

Kit.run({
    init = Game.init,
    shotPath = "build/vault-shot.png",
    extra = function(t)
        t.room = State.room
        t.hp = State.hp
        t.keys = State.keys
        t.bombsleft = State.bombs
        t.mode = Kit.mode
    end,
})
