-- Lob: tuning constants. Smoke builds shrink the ceremony timers so a
-- full match fits in a smoke run.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    VMIN = 15,              -- launch speed range across the power meter
    VMAX = 60,
    ELEV_COS = 0.7071,      -- fixed 45-degree mortar elevation
    ELEV_SIN = 0.7071,
    ROT_SPEED = 1.6,        -- azimuth radians/sec on d-pad (docked fallback)
    POWER_CADENCE = 0.9,    -- seconds for the held-A meter to sweep 0 -> 1
    WIND_MAX = 6,           -- horizontal (screen-x) shell acceleration

    CARVE_R = 3,
    BLAST_R = 4.5,          -- damage radius; < 2 is a direct hit (2 dmg)
    MAX_HP = 3,
    ROUNDS = 2,             -- round wins to take the match

    AI_ERR0 = 6,            -- foe aim error, brackets tighter each shot
    AI_DECAY = 0.75,
    AI_ERR_MIN = 1.5,
    AP_ERR = 3.5,           -- smoke autopilot error for the player side

    BANNER_T = SMOKE_BUILD and 0.3 or 1.0,
    AI_THINK_T = SMOKE_BUILD and 0.3 or 1.0,
    RESOLVE_T = SMOKE_BUILD and 0.4 or 0.9,
}
