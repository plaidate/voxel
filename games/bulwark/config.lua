-- Bulwark: tuning constants. Smoke builds shorten the phase timers so a
-- full game fits in a smoke run.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    VMIN = 15,              -- shell speed range
    VMAX = 55,
    ELEV_COS = 0.7071,      -- fixed 45-degree lob
    ELEV_SIN = 0.7071,
    CARVE_R = 2,

    KEEP_HP = 6,
    ROUNDS = 3,             -- sieges to survive
    CANNON_CD = 0.8,
    POWER_CADENCE = 0.9,    -- held-A meter sweep, as in Lob
    CAT_ERR = 2.5,          -- catapult aim error
    AP_ERR = 1.5,           -- smoke autopilot cannon error

    BUILD_T = SMOKE_BUILD and 6 or 20,
    SIEGE_T = SMOKE_BUILD and 10 or 14,
    BANNER_T = SMOKE_BUILD and 0.3 or 1.2,
}
