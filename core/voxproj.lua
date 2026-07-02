-- Voxel core: parabolic projectile integrator for artillery shells.
-- Games own the launch offsets and what happens on impact; this owns the
-- flight math so every shell in the package flies the same way.

VoxProj = {}

function VoxProj.launch(x, y, z, az, v, elevCos, elevSin)
    local ca, sa = math.cos(az), math.sin(az)
    local hv = v * elevCos
    return { x = x, y = y, z = z, vx = hv * ca, vy = hv * sa, vz = v * elevSin, t = 8 }
end

-- one substep; returns true on impact with terrain or the room bounds
function VoxProj.step(p, dt, gravity, windX)
    p.vx = p.vx + (windX or 0) * dt
    p.vz = p.vz - gravity * dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.z = p.z + p.vz * dt
    return Vox.solid(math.floor(p.x), math.floor(p.y), math.floor(p.z))
end
