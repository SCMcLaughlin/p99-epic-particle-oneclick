
package.path = package.path .. ";scripts/?.lua"

local Dir = require "Dir"

local loadfile  = loadfile
local assert    = assert
local string    = string
local io        = io

local function processFile(path)
    local script    = assert(loadfile("scripts/" .. path))
    local d         = assert(string.dump(script))

    local name  = path:match("[^%.]+")
    local f     = assert(io.open(string.format("script_%s.h", name), "w+"))

    f:write(string.format([[

static unsigned char script_%s[] = {
    ]], name))

    for i = 1, #d do
        if i ~= 1 then
            if i%16 == 1 then
                f:write(",\n    ")
            else
                f:write(", ")
            end
        end

        f:write(string.format("0x%02x", d:byte(i)))
    end

    f:write(string.format([[

};

static int loader_%s(lua_State* L)
{
    if (luaL_loadbuffer(L, (const char*)script_%s, sizeof(script_%s), "%s"))
        lua_error(L);

    if (lua_pcall(L, 0, 1, 0))
        lua_error(L);

    return 1;
}
]], name, name, name, name))

    f:close()
end

for path in Dir.iter("scripts/*") do
    if path ~= "." and path ~= ".." then
        processFile(path)
    end
end
