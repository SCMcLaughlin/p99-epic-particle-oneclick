
#include <lua.h>
#include <lualib.h>
#include <luaconf.h>
#include <lauxlib.h>
#include <zlib.h>
#include <zconf.h>
#include <stdarg.h>
#include <stdio.h>
#include <windows.h>

#include "script_BinUtil.h"
#include "script_Buffer.h"
#include "script_Class.h"
#include "script_CRC.h"
#include "script_crc_table.h"
#include "script_File.h"
#include "script_Frag34.h"
#include "script_FragHeader.h"
#include "script_PFS.h"
#include "script_Struct.h"
#include "script_Util.h"
#include "script_WLD.h"
#include "script_Zlib.h"
#include "script_main.h"

void errmsg(const char* fmt, ...)
{
	char* buf;
	int len;
	va_list check;
	va_list args;

	va_start(check, fmt);
	va_start(args, fmt);

	len = vsnprintf(NULL, 0, fmt, check);

	if (len > 0)
	{
		len++; /* Include null terminator */

		buf = (char*)malloc(len);

		if (buf)
		{
			len = vsnprintf(buf, len, fmt, args);

			if (len > 0)
				MessageBoxA(NULL, buf, NULL, MB_OK | MB_ICONERROR | MB_TASKMODAL);

			free(buf);
		}
	}

	va_end(check);
	va_end(args);
}

static void lua_pushloaderfunc(lua_State* L, lua_CFunction func, const char* name)
{
	lua_pushcfunction(L, func);
	lua_setfield(L, -2, name);
}

#define lua_pushloader(L, name) lua_pushloaderfunc((L), loader_##name, #name)

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR pCmdLine, int nCmdShow)
{
	lua_State* L = luaL_newstate();
	int rc = 0;

	if (L == NULL)
	{
		errmsg("Error: initialization failed");
		return 1;
	}

	luaL_openlibs(L);

	/* Embedded script loaders */

	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");

	lua_pushloader(L, BinUtil);
    lua_pushloader(L, Buffer);
    lua_pushloader(L, Class);
    lua_pushloader(L, CRC);
    lua_pushloader(L, crc_table);
    lua_pushloader(L, File);
    lua_pushloader(L, Frag34);
    lua_pushloader(L, FragHeader);
    lua_pushloader(L, PFS);
    lua_pushloader(L, Struct);
    lua_pushloader(L, Util);
    lua_pushloader(L, WLD);
    lua_pushloader(L, Zlib);

	lua_pop(L, 2); /* Pop preload and package tables */

	/* Load and run the main script */

	if (luaL_loadbuffer(L, (const char*)script_main, sizeof(script_main), "main") ||
		lua_pcall(L, 0, 0, 0))
	{
		errmsg("Error: %s", lua_tostring(L, -1));
		lua_pop(L, 1);
		rc = 2;
	}
	else
	{
		MessageBoxA(NULL, "Successfully fixed epic particles!\nMake sure you log all the way out to see the results.",
			"Success", MB_OK | MB_TASKMODAL);
	}

	lua_close(L);
	return rc;
}

/*
	Need to re-export the zlib funcs so luajit's FFI can see them.
	Microsoft's compilers don't appear to offer a more sensible way of doing this...
*/

#define EXPORT extern __declspec(dllexport)

EXPORT unsigned long zlib_compressBound(unsigned long len)
{
	return compressBound(len);
}

EXPORT int zlib_compress(unsigned char* dst, unsigned long* dlen, const unsigned char* src, unsigned long slen)
{
	return compress2(dst, dlen, src, slen, 9);
}

EXPORT int zlib_uncompress(unsigned char* dst, unsigned long* dlen, const unsigned char* src, unsigned long slen)
{
	return uncompress(dst, dlen, src, slen);
}

/* fwrite also */
EXPORT size_t zae_fwrite(const void* a, size_t b, size_t c, void* d)
{
	return fwrite(a, b, c, d);
}
