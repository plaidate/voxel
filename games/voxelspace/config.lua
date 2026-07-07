-- Voxelspace: tuning constants.

Config = {
    FPS = 50,               -- the demo earns the Playdate's max refresh
    DT = 1 / 50,

    -- terrain (map size is fixed at 256 -- the renderer masks with &255)
    CELL = 2,               -- world units per map cell (wider = broader hills)
    HMAX = 130,             -- tallest terrain, world units
    WATER = 0.32,           -- water level, fraction of normalized noise
    SNOW = 0.78,            -- snowline, fraction of normalized noise

    -- renderer
    COLS = 200,             -- screen columns (400 / COLW)
    COLW = 2,
    HORIZON = 96,           -- screen y of the horizon at level flight
    SCALE = 300,            -- vertical projection scale
    ZNEAR = 6,
    ZFAR = 800,
    DZ0 = 1.0,              -- first depth step
    DZK = 1.06,             -- depth step growth per iteration (LOD)
    FOG1 = 140,             -- fog starts here...
    FOGSTEP = 110,          -- ...and lifts one more dither level per step
    FLATZ = 420,            -- past here haze flattens to one shade
    FLATSHADE = 12,         -- ...this one

    -- flight model
    SPEED = 42,             -- cruise, world units/s
    BOOST = 95,             -- with A held
    TURN = 0.5,             -- crank gearing: heading deg per crank deg
    DTURN = 1.5,            -- d-pad left/right turn rate, rad/s
    CLIMB = 26,             -- up/down altitude rate, units/s
    CLEARANCE = 10,         -- minimum height above the ground
    ALTMAX = 150,
    PITCH_LERP = 5,         -- horizon tilt smoothing toward climb input
}
