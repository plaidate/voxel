-- Marble: tuning constants.

Config = {
    DT = 1 / 30,
    GRAVITY = 34,

    SLOPE_K = 26,           -- downhill acceleration per unit gradient
    STEER = 14,             -- d-pad acceleration
    FRICTION = 1.4,         -- per-second velocity decay factor
    VMAX = 34,
    BOOST = 20,             -- full-charge burst speed
    BOUNCE = 0.55,          -- wall restitution
    MARBLES = 3,

    POWER_CADENCE = 0.9,    -- crank wind rate (full in ~1s of cranking)
    COURSE_T = SMOKE_BUILD and 35 or 45,
    BANNER_T = SMOKE_BUILD and 0.4 or 1.2,
}
