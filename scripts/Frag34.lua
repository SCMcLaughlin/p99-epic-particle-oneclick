
local Struct        = require "Struct"
local Class         = require "Class"
local FragHeader    = require "FragHeader"
local bit           = require "bit"

local band      = bit.band
local lshift    = bit.lshift
local bor       = bit.bor
local bnot      = bit.bnot

local Frag = Class("Frag34", FragHeader)

local b = {
    7, 8, 10, 14, 15, 16, 17
}

function Frag:getFlagBit(n)
    return band(self.flag, lshift(1, b[n])) ~= 0
end

function Frag:setFlagBit(n, v)
    n = lshift(1, b[n])

    if v then
        self.flag = bor(self.flag, n)
    else
        self.flag = band(self.flag, bnot(n))
    end
end

return Struct([[
    WLDFragHeader   header;
    uint32_t        setting[2];
    uint32_t        mode;
    uint32_t        flag;
    uint32_t        simultaneous;
    float           unknownA[5];
    float           sphereRadius;
    float           coneAngle;
    uint32_t        lifetime;
    float           velocity;
    float           vectorZ;
    float           vectorX;
    float           vectorY;
    uint32_t        emitDelay;
]], Frag)
