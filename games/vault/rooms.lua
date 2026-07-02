-- Vault: the dungeon as data. Rooms live on the 96x64 grid; walls are
-- {x0, y0, x1, y1, height} (height <= 2 is jumpable), goo is {cx, cy, r},
-- and exits name the neighbouring room per side. A locked side gets
-- white door columns until a key (or a bomb) opens the way.
--
--          [E idol]
--   [C] -- [B] -- [D]
--          [A start]

Rooms = {
    A = {
        exits = { n = "B" },
        pots = { { 30, 20 }, { 66, 20 }, { 30, 44 }, { 66, 44 } },
        walls = { { 44, 28, 51, 35, 2 } },
    },
    B = {
        exits = { s = "A", w = "C", e = "D" },
        locked = { e = true },
        key = { 48, 10 },
        grubs = { { 30, 20 }, { 64, 44 } },
        walls = {
            { 20, 14, 40, 16, 4 },
            { 56, 46, 76, 48, 4 },
            { 44, 8, 51, 13, 2 },
        },
        pots = { { 12, 54 }, { 84, 10 } },
    },
    C = {
        exits = { e = "B" },
        goo = { { 34, 32, 9 }, { 62, 30, 8 } },
        walls = {
            { 24, 26, 30, 38, 2 },
            { 40, 22, 46, 30, 2 },
            { 52, 34, 58, 42, 2 },
            { 68, 26, 74, 34, 2 },
        },
        bomb = { 14, 32 },
        pots = { { 14, 10 }, { 14, 54 } },
    },
    D = {
        exits = { w = "B", n = "E" },
        grubs = { { 40, 20 }, { 60, 30 }, { 48, 46 } },
        walls = { { 30, 26, 66, 28, 2 } },
        pots = { { 34, 24 }, { 48, 24 }, { 62, 24 } },
    },
    E = {
        exits = { s = "D" },
        goo = { { 48, 26, 12 } },
        walls = { { 44, 22, 51, 29, 2 }, { 46, 30, 49, 40, 1 } },
        grubs = { { 20, 20 }, { 76, 20 }, { 20, 44 }, { 76, 44 } },
        idol = { 47, 25 },
    },
}
