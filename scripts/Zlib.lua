
local ffi       = require "ffi"
local BinUtil   = require "BinUtil"

local C         = ffi.C
local assert    = assert

ffi.cdef[[
unsigned long zlib_compressBound(unsigned long srcLen);
int zlib_compress(uint8_t* dst, unsigned long* dstLen, const uint8_t* src, unsigned long srcLen);
int zlib_uncompress(uint8_t* dst, unsigned long* dstLen, const uint8_t* src, unsigned long srcLen);
]]

local Zlib = {}

local lenArg = BinUtil.ULong.Arg()

function Zlib.decompressToBuffer(data, len, outbuf, outbufLen)
    lenArg[0] = outbufLen
    local res = C.zlib_uncompress(outbuf, lenArg, data, len)
    assert(res == 0)
end

function Zlib.compressToBuffer(data, len, outbuf, outbufLen)
    lenArg[0] = outbufLen
    local res = C.zlib_compress(outbuf, lenArg, data, len)
    assert(res == 0)
    return lenArg[0]
end

return Zlib
