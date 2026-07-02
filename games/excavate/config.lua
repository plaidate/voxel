-- Excavate: tuning constants.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    SPEED = 14,
    JUMP_VEL = 12,
    MAX_HP = 3,
    IFRAMES = 1.2,

    DIG_CD = 0.45,
    DIG_R = 2,
    FOSSILS_BASE = 4,       -- fossils = base + level

    SHIFT_T = SMOKE_BUILD and 60 or 90,
    BANNER_T = SMOKE_BUILD and 0.4 or 1.2,
}
