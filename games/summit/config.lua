-- Summit: tuning constants.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    SPEED = 15,
    BRUTE_SPEED = 8,
    BRUTE_SPEED_RND = 0.8,  -- extra per round
    JUMP_VEL = 12,

    SHOVE_R = 3.2,          -- shove reach
    SHOVE_KB = 46,
    SHOVE_CD = 0.7,
    BRUTE_KB = 26,
    BRUTE_CD = 1.2,
    SPIN_R = 4.5,           -- full-charge radial blast
    SPIN_KB = 64,
    SPIN_RATE = 0.7,        -- crank turns to charge the spin

    BRUTES_BASE = 2,        -- brutes = base + round (cap 6)
    EROSION_T = SMOKE_BUILD and 6 or 9,
    BANNER_T = SMOKE_BUILD and 0.4 or 1.2,
}
