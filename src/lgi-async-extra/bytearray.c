/// Mappings for [GByteArray](https://docs.gtk.org/glib/struct.ByteArray.html).
//
// @module bytearray
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <glib-2.0/glib.h>

#ifdef _WIN32
#define LUA_MOD_EXPORT __declspec(dllexport)
#else
#define LUA_MOD_EXPORT extern
#endif

#define LUA_BYTEARRAY "bytearray"


typedef struct bytearray {
    GByteArray* bytearray;
} bytearray;


static int
bytearray_new(lua_State* L)
{
    bytearray* array = lua_newuserdata (L, sizeof(bytearray));
    if (!array) {
        return luaL_error(L, "failed to create bytearray userdata");
    }
    array->bytearray = g_byte_array_new();
    luaL_setmetatable(L, LUA_BYTEARRAY);
    return 1;
}


static int
bytearray_len(lua_State* L)
{
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);
    lua_pushinteger(L, array->bytearray->len);
    return 1;
}


static int
bytearray_tostring(lua_State* L)
{
    return luaL_error(L, "not yet implemented");
}


static int
bytearray_index(lua_State* L)
{
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);

    if (lua_isinteger(L, 2)) {
        size_t index = lua_tointeger(L, 2);
        if (index >= array->bytearray->len) {
            return luaL_error(L, "index out of range");
        }
        lua_pushinteger(L, *(array->bytearray->data + index));
        return 1;
    }

    // TODO: Figure out if error checking is necessary
    luaL_getmetatable(L, LUA_BYTEARRAY);
    lua_pushvalue(L, 2);
    lua_rawget(L, -2);
    return 1;
}


static int
bytearray_newindex(lua_State* L)
{
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);

    size_t index = lua_tointeger(L, 2);
    if (index >= array->bytearray->len) {
        return luaL_error(L, "index out of range");
    }

    guint8* value = array->bytearray->data + index;
    *value = lua_tointeger(L, 3);
    return 1;
}


static const struct luaL_Reg bytearray_mt [] = {
    { "__len", bytearray_len },
    { "__tostring", bytearray_tostring },
    { "__index", bytearray_index },
    { "__newindex", bytearray_newindex },
    {NULL, NULL}
};

static const struct luaL_Reg bytearray_lib [] = {
    {"new", bytearray_new},
    {NULL, NULL}
};


LUA_MOD_EXPORT int luaopen_lgi_async_extra_bytearray(lua_State* L)
{
    luaL_newmetatable(L, LUA_BYTEARRAY);
    luaL_setfuncs(L, bytearray_mt, 0);

    luaL_newlib(L, bytearray_lib);
    return 1;
}
