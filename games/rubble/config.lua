-- Rubble: tuning constants.

Config = {
    DT = 1 / 30,

    MOVE_SPEED = 16,        -- player, voxels/sec
    JUMP_VEL = 12,
    GRAVITY = 34,
    MAX_HP = 3,
    IFRAMES = 1.2,
    KNOCKBACK = 40,

    ENEMY_SPEED = 5.5,
    ENEMY_SPEED_WAVE = 0.4, -- extra speed per wave
    CHEW_PERIOD = 1.1,      -- blocked grubs carve through cover this often
    CHEW_R = 2,

    SHOT_SPEED = 48,
    SHOT_RANGE = 80,
    FIRE_COOLDOWN = 0.22,
    CARVE_R = 2,

    WAVE_BASE = 2,          -- enemies per wave = WAVE_BASE + wave
    SPAWN_GAP = 0.8,
}
