
local PFS   = require "PFS"
local WLD   = require "WLD"
local File  = require "File"

local pfs = PFS("gequip.s3d")
local wld = WLD(pfs:getEntryByName("gequip.wld"))

for _, f34 in wld:getFragsByType(0x34) do
    if f34.mode == 1 and f34.sphereRadius == 0.0 then
        f34.sphereRadius = 0.01
    end
end

-- Make a backup copy before we commit changes
File.copy("gequip.s3d", "gequip.zae")

pfs:importFromMemory("gequip.wld", wld:getData())
pfs:save()
