-- Crumble: tuning constants.

Config = {
    DT = 1 / 30,

    MOVE_SPEED = 16,
    JUMP_VEL = 12,       -- B hop: clears ~2 voxels
    SPRING_MAX = 9,      -- extra jump velocity at full crank charge
    GRAVITY = 34,
    MAX_HP = 3,
    IFRAMES = 1.0,

    SLIME_T0 = 10,       -- seconds before the first rise
    SLIME_MIN = 4,       -- fastest rise interval
    SLIME_DECAY = 0.92,  -- interval multiplier per rise

    CRUMBLE_T = 0.55,    -- stood-on columns lose a voxel this often
    GEMS = 3,            -- gems alive at once
    GEM_SCORE = 10,
}
