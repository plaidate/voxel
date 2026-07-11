-- Voxel core: the smoke-test harness as a first-class module.
--
-- The Makefile stages smokeflag.lua into every build: SMOKE_BUILD=false for
-- release, true for `make smoke`. When off, everything here is a no-op and
-- games pay nothing. When on: counters, a pcall-wrapped update writing
-- errors to the "err" datastore, a 90-frame heartbeat to "smoke", periodic
-- PNG screenshots, and an autopilot hook the game's input module consults.

import "smokeflag"

Harness = {
    enabled = SMOKE_BUILD,
    counters = {},
    autopilot = nil, -- game sets Harness.autopilot = function() ... end
    extra = nil,     -- optional fn(tbl) adding fields to the heartbeat
    shotPath = nil,  -- host path for screenshots (set by the game or smoke.sh convention)
}

-- a stale "err" from a previous run must not masquerade as a current one
if Harness.enabled then
    playdate.datastore.delete("err")
end

local errLatched = false

function Harness.count(key, n)
    if not Harness.enabled then return end
    Harness.counters[key] = (Harness.counters[key] or 0) + (n or 1)
end

function Harness.set(key, val)
    if not Harness.enabled then return end
    Harness.counters[key] = val
end

-- wraps the real per-frame update; called from each game's playdate.update
function Harness.frame(frame, updateFn)
    if not Harness.enabled then
        updateFn()
        return
    end
    local ok, err = pcall(updateFn)
    if not ok and not errLatched then
        -- latch the FIRST error: later failures are usually fallout
        errLatched = true
        playdate.datastore.write({ err = tostring(err) }, "err")
    end
    if frame % 90 == 0 then
        local t = {}
        for k, v in pairs(Harness.counters) do t[k] = v end
        t.frame = frame
        if Harness.extra then
            pcall(Harness.extra, t)
        end
        playdate.datastore.write(t, "smoke")
    end
    if Harness.shotPath and playdate.simulator and (frame == 20 or frame % 300 == 0) then
        local img = playdate.graphics.getDisplayImage()
        playdate.simulator.writeToFile(img, Harness.shotPath)
        playdate.simulator.writeToFile(img, (Harness.shotPath:gsub("%.png$", "-" .. frame .. ".png")))
    end
end
