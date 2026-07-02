-- Herd: tuning constants. Smoke builds shorten the level timer.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    SPEED = 4.5,            -- sheep walk speed, voxels/sec
    SPLAT_VZ = 15,          -- landing faster than this is fatal (~3.5 voxel fall)
    TOTAL = 12,             -- sheep per level
    QUOTA_BASE = 7,         -- quota = base + min(level-1, 3)

    RATE_MIN = 0.3,         -- release rate range, sheep/sec (crank)
    RATE_MAX = 2.5,

    DIG_CD = 0.4,
    DIG_R = 2,
    BLAST_R = 3,
    BLASTS = 5,             -- blast charges per level

    LEVEL_T = SMOKE_BUILD and 55 or 75,
    BANNER_T = SMOKE_BUILD and 0.4 or 1.2,
}
