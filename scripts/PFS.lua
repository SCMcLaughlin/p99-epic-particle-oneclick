
local BinUtil   = require "BinUtil"
local Class     = require "Class"
local Struct    = require "Struct"
local Buffer    = require "Buffer"
local Zlib      = require "Zlib"
local File      = require "File"
local CRC       = require "CRC"
local ffi       = require "ffi"
local Util      = require "Util"

local table     = table
local ipairs    = ipairs

local Header = Struct[[
    uint32_t offset;
    uint32_t signature;
    uint32_t unknown;
]]

local BlockHeader = Struct[[
    uint32_t deflatedLen;
    uint32_t inflatedLen;
]]

local DirEntry = Struct[[
    uint32_t crc;
    uint32_t offset;
    uint32_t inflatedLen;
]]

local ProcessedEntry = Struct[[
    uint32_t crc;
    uint32_t offset;
    uint32_t inflatedLen;
    uint32_t deflatedLen;
]]

local Signature = BinUtil.toFileSignature("PFS ")

local PFS = Class("PFS")

function PFS.new(path)
    local data, fileLen = File.openBinary(path)
    if not data then
        error("\nCould not open '".. path .."'.\n\nAre you running this from your EQ folder?")
    end

    local p = Header:sizeof()

    local function tooShort()
        if p > fileLen then
            error("File is too short for the length of data indicated: '".. path .."'")
        end
    end

    tooShort()
    local header = Header:cast(data)
    if header.signature ~= Signature then
        error("File is not a valid PFS archive: '".. path .."'")
    end

    p = header.offset
    tooShort()
    local n = BinUtil.Uint32:cast(data + p)[0]

    p = p + BinUtil.Uint32:sizeof()
    tooShort()

    local pfs = {
        _path           = path,
        _rawData        = data,
        _decompressed   = {},
        _names          = {},
        _byName         = {},
        _byExt          = {},
    }

    PFS:instance(pfs)

    for i = 1, n do
        local src = DirEntry:cast(data + p)
        p = p + DirEntry:sizeof()
        tooShort()

        local ent = ProcessedEntry()
        ent.crc            = src.crc
        ent.offset         = src.offset
        ent.inflatedLen    = src.inflatedLen

        local memPos = p
        p = src.offset
        tooShort()

        local ilen      = 0
        local totalLen  = src.inflatedLen
        while ilen < totalLen do
            local bh = BlockHeader:cast(data + p)
            p = p + BlockHeader:sizeof()
            tooShort()
            p = p + bh.deflatedLen
            tooShort()
            ilen = ilen + bh.inflatedLen
        end
        ent.deflatedLen = p - src.offset

        p       = memPos
        pfs[i]  = ent
    end

    table.sort(pfs, function(a, b) return a.offset < b.offset end)

    -- Retrieve name data entry and release it so it will be gc'd after we are done with it
    n = #pfs
    local nameData = pfs:_decompressEntry(n)
    pfs[n] = nil
    pfs._decompressed[n] = nil

    n = BinUtil.Uint32:cast(nameData)[0]
    p = BinUtil.Uint32:sizeof()

    for i = 1, n do
        local len = BinUtil.Uint32:cast(nameData + p)[0]
        p = p + BinUtil.Uint32:sizeof()
        local name = BinUtil.Char:cast(nameData + p)
        p = p + len

        name = ffi.string(name, len - 1) -- Cut trailing null byte

        pfs._names[i] = name
        pfs._byName[name] = i
        pfs:_addByExt(name, i)
    end

    return pfs
end

function PFS:_addByExt(name, n)
    local ext = name:match("[^%.]+$")
    local t = self._byExt[ext]
    if not t then
        t = {}
        self._byExt[ext] = t
    end
    table.insert(t, n)
end

function PFS:getEntry(i)
    local ent = self._decompressed[i]
    if ent then return ent, ffi.sizeof(ent) end

    return self:_decompressEntry(i)
end

function PFS:getEntryByName(name)
    local i = self._byName[name]
    if i then return self:getEntry(i) end
end

function PFS:export(i, path)
    local file      = File(path, "wb+")
    local data, len = self:getEntry(i)

    file:writeBinary(data, len)
    file:close()
end

function PFS:exportByName(name, path)
    if not path then path = name end

    local i = self._byName[name]
    if i then self:export(i, path) end
end

function PFS:importFromMemory(name, data, len)
    --self:reload()

    local n = self._byName[name]
    if not n then n = #self + 1 end

    local ent = ProcessedEntry()

    ent.crc         = CRC.calcString(name)
    ent.inflatedLen = len

    self[n]                 = ent
    self._names[n]          = name
    self._byName[name]      = n
    self._decompressed[n]   = data
    self:_addByExt(name, n)
end

function PFS:_decompressEntry(i)
    local ent = self[i]
    if not ent then return end

    local data      = self._rawData + ent.offset
    local ilen      = ent.inflatedLen
    local read      = 0
    local pos       = 0
    local buffer    = BinUtil.Byte.Array(ilen)

    while read < ilen do
        local bh = BlockHeader:cast(data + pos)
        pos = pos + BlockHeader:sizeof()

        Zlib.decompressToBuffer(data + pos, bh.deflatedLen, buffer + read, ilen - read)

        read = read + bh.inflatedLen
        pos  = pos + bh.deflatedLen
    end

    self._decompressed[i] = buffer

    return buffer, ilen
end

function PFS._compressEntry(data, len)
    local buf = Buffer()
    local tmp = BinUtil.Byte.Array(8192)

    while len > 0 do
        local r     = len < 8192 and len or 8192
        local bh    = BlockHeader()

        bh.inflatedLen = r

        local dlen = Zlib.compressToBuffer(data, r, tmp, 8192)
        bh.deflatedLen = dlen

        buf:push(bh, BlockHeader:sizeof())
        buf:push(tmp, dlen)

        len     = len - r
        data    = data + r
    end

    return buf:get()
end

function PFS:hasFile(name)
    return self._byName[name] ~= nil
end

function PFS:names()
    local names = self._names
    local i = 0
    return function()
        i = i + 1
        return names[i]
    end
end

function PFS:getEntryByExtension(ext)
    local byExt = self._byExt[ext]
    if byExt then
        return self:getEntry(byExt[1])
    end
end

function PFS:namesByExtension(ext)
    local ext = self._byExt[ext]

    if not ext then return Util.nullFunc end

    local names = self._names
    local i     = 0

    return function()
        i = i + 1
        local index = ext[i]
        if index then
            return names[index]
        end
    end
end

function PFS:save()
    local header        = Header()
    header.signature    = Signature
    header.unknown      = 131072

    local p = Header:sizeof()
    local c = #self

    local dirEntries    = {}
    local dataBuf       = Buffer()
    local nameBuf       = Buffer()

    local n = BinUtil.Uint32.Arg(c)
    nameBuf:push(n, BinUtil.Uint32:sizeof())

    local decomp    = self._decompressed
    local rawData   = self._rawData
    local names     = self._names

    for i = 1, c do
        local ent   = self[i]
        local name  = names[i]

        -- Write name with 32bit length prepended, including null terminator
        n[0] = #name + 1
        nameBuf:push(n, BinUtil.Uint32:sizeof())
        nameBuf:push(name, n[0])

        local e         = DirEntry()
        e.crc           = ent.crc
        e.offset        = p
        e.inflatedLen   = ent.inflatedLen
        dirEntries[i]   = e

        local len
        local d = decomp[i]

        if d then
            local data
            data, len = PFS._compressEntry(d, ent.inflatedLen)
            dataBuf:push(data, len)
        else
            len = ent.deflatedLen
            dataBuf:push(rawData + ent.offset, len)
        end

        p = p + len
    end

    -- Compress names entry so we can tell the header the offset after it
    local e         = DirEntry()
    e.crc           = 0x61580AC9 -- Always this
    e.offset        = p
    e.inflatedLen   = nameBuf:length()
    table.insert(dirEntries, e)

    table.sort(dirEntries, function(a, b) return a.crc < b.crc end)

    local addNames = Buffer()
    addNames:push(PFS._compressEntry(nameBuf:get()))
    p = p + addNames:length()

    header.offset = p

    -- Start writing to file
    local file = File(self._path, "wb+")

    -- Header
    file:writeBinary(header, Header:sizeof())

    -- Compressed entries
    file:writeBinary(dataBuf:get())

    -- Names entry
    file:writeBinary(addNames:get())

    -- Offset and crc list in order of crc
    c       = #dirEntries
    n[0]    = c
    file:writeBinary(n, BinUtil.Uint32:sizeof())

    for i = 1, c do
        local e = dirEntries[i]
        file:writeBinary(e, DirEntry:sizeof())
    end

    file:close()
end

return PFS
