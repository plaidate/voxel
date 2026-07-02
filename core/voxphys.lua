-- Voxel core: shared actor physics on the Vox grid. Actors carry x, y, z
-- (feet height), vz, hw (footprint half-width) and grounded.

VoxPhys = {}

-- highest standing height under a square footprint
function VoxPhys.groundAt(x, y, hw)
    local floor = math.floor
    local g = Vox.heightAt(floor(x - hw), floor(y - hw))
    local h = Vox.heightAt(floor(x + hw), floor(y - hw))
    if h > g then g = h end
    h = Vox.heightAt(floor(x - hw), floor(y + hw))
    if h > g then g = h end
    h = Vox.heightAt(floor(x + hw), floor(y + hw))
    if h > g then g = h end
    return g
end

-- horizontal move with automatic 1-voxel step-up; taller terrain blocks
function VoxPhys.tryMove(e, nx, ny)
    local g = VoxPhys.groundAt(nx, ny, e.hw)
    if g - e.z <= 1.01 then
        e.x, e.y = nx, ny
        if e.z < g then e.z = g end
        return true
    end
    return false
end

-- ---- tunnel-aware variants -------------------------------------------
-- heightAt physics stands actors on the COLUMN TOP, which makes tunnels
-- impassable. These variants stand actors on the surface directly
-- beneath them, honor headroom, and bump heads on tunnel roofs.

-- surface height directly beneath fromZ (ignores roofs above)
function VoxPhys.support(x, y, fromZ)
    local s = math.floor(fromZ + 0.001)
    if s > Vox.H then s = Vox.H end
    while s > 0 and not Vox.solid(x, y, s - 1) do s = s - 1 end
    return s
end

local function supportAt(x, y, hw, z)
    local floor = math.floor
    local g = VoxPhys.support(floor(x - hw), floor(y - hw), z)
    local h = VoxPhys.support(floor(x + hw), floor(y - hw), z)
    if h > g then g = h end
    h = VoxPhys.support(floor(x - hw), floor(y + hw), z)
    if h > g then g = h end
    h = VoxPhys.support(floor(x + hw), floor(y + hw), z)
    if h > g then g = h end
    return g
end
VoxPhys.supportAt = supportAt

local function headroomAt(x, y, hw, s, hr)
    local floor = math.floor
    for dz = 0, hr - 1 do
        local z = s + dz
        if Vox.solid(floor(x - hw), floor(y - hw), z)
            or Vox.solid(floor(x + hw), floor(y - hw), z)
            or Vox.solid(floor(x - hw), floor(y + hw), z)
            or Vox.solid(floor(x + hw), floor(y + hw), z) then
            return false
        end
    end
    return true
end

function VoxPhys.tryMoveTun(e, nx, ny, hr)
    local s = supportAt(nx, ny, e.hw, e.z + 1.01)
    if s - e.z <= 1.01 and headroomAt(nx, ny, e.hw, s, hr or 3) then
        e.x, e.y = nx, ny
        if e.z < s then e.z = s end
        return true
    end
    return false
end

function VoxPhys.physZTun(e, dt, gravity, hr)
    local s = supportAt(e.x, e.y, e.hw, e.z)
    e.vz = e.vz - gravity * dt
    if e.vz > 0 and Vox.solid(math.floor(e.x), math.floor(e.y),
            math.floor(e.z) + (hr or 3)) then
        e.vz = 0
    end
    e.z = e.z + e.vz * dt
    if e.z <= s and e.vz <= 0 then
        e.z = s
        e.vz = 0
        e.grounded = true
    else
        e.grounded = false
    end
end

function VoxPhys.physZ(e, dt, gravity)
    local g = VoxPhys.groundAt(e.x, e.y, e.hw)
    e.vz = e.vz - gravity * dt
    e.z = e.z + e.vz * dt
    if e.z <= g and e.vz <= 0 then
        e.z = g
        e.vz = 0
        e.grounded = true
    else
        e.grounded = false
    end
end
