-- Voxel core: tiny voxel models for actors, authored as layer strings.
--
--   VoxModel.fromLayers({
--       { "2.2", "2.2" },   -- z = 0, rows back -> front, chars = materials
--       { "222", "222" },   -- z = 1  ('.' = empty, 1..4 = Vox materials)
--   })
--
-- Voxels are centered on x/y and sorted back-to-front, bottom-to-top at
-- build time so VoxModel.draw is a straight painter loop of Vox.drawBlock.

VoxModel = {}

function VoxModel.fromLayers(layers)
    local vox = {}
    local maxc, maxr = 0, 0
    for zi, layer in ipairs(layers) do
        local z = zi - 1
        for r, row in ipairs(layer) do
            if r > maxr then maxr = r end
            for c = 1, #row do
                local ch = row:sub(c, c)
                if ch ~= "." then
                    if c > maxc then maxc = c end
                    vox[#vox + 1] = { c - 1, r - 1, z, tonumber(ch) }
                end
            end
        end
    end
    table.sort(vox, function(a, b)
        if a[2] ~= b[2] then return a[2] < b[2] end
        if a[3] ~= b[3] then return a[3] < b[3] end
        return a[1] < b[1]
    end)
    return {
        vox = vox,
        cx = (maxc - 1) / 2,
        cy = (maxr - 1) / 2,
        w = maxc,
        h = #layers,
    }
end

-- draw with feet at world (wx, wy, wz); wx/wy are the model's center
function VoxModel.draw(model, wx, wy, wz)
    local cx, cy = model.cx, model.cy
    for i = 1, #model.vox do
        local v = model.vox[i]
        Vox.drawBlock(wx + v[1] - cx, wy + v[2] - cy, wz + v[3], v[4])
    end
end
