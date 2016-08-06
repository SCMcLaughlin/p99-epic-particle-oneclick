
local Struct    = require "Struct"
local ffi       = require "ffi"

ffi.cdef[[
typedef int         BOOL;
typedef uint32_t    DWORD;
typedef void*       HANDLE;

typedef struct FILETIME {
    DWORD   dwLowDateTime;
    DWORD   dwHighDateTime;
} FILETIME;
]]

local FindData = Struct.named("WIN32_FIND_DATA", [[
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    char     cFileName[260];
    char     cAlternateFileName[14];
]])

ffi.cdef[[
HANDLE  FindFirstFileA(const char* lpFileName, WIN32_FIND_DATA* lpFindFileData);
BOOL    FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATA* lpFindFileData);
BOOL    FindClose(HANDLE hFindFile);
]]

local INVALID_HANDLE_VALUE = ffi.cast("void*", -1)
local C = ffi.C

local Dir = {}

function Dir.iter(path)
    local findData  = FindData.Arg()
    local h         = C.FindFirstFileA(path, findData)

    return function()
        if h == INVALID_HANDLE_VALUE then return end

        local str = ffi.string(findData[0].cFileName)
        local ret = C.FindNextFileA(h, findData)

        if ret == 0 then
            h = INVALID_HANDLE_VALUE
            C.FindClose(h)
        end

        return str
    end
end

return Dir
