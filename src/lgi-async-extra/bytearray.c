/// Mappings for [GByteArray](https://docs.gtk.org/glib/struct.ByteArray.html).
//
// @module bytearray
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <glib-2.0/glib.h>
#include <glib-object.h>

#ifdef _WIN32
#define LUA_MOD_EXPORT __declspec(dllexport)
#else
#define LUA_MOD_EXPORT extern
#endif

#define LUA_BYTEARRAY "bytearray"

const char* l_get_type_name = "local val = ...; return val._name";


typedef struct bytearray {
    GByteArray* bytearray;
} bytearray;


/// Constructors
// @section constructors

/// Creates a new ByteArray.
//
// @function new
// @treturn ByteArray
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


///
// @type ByteArray


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
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);
    guint size = array->bytearray->len;
    gchar* str = g_utf8_make_valid(array->bytearray->data, size);
    lua_pushlstring(L, str, size);
    return 1;
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


static int
bytearray_gc(lua_State* L)
{
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);
    g_byte_array_unref(array->bytearray);

    /* Unset the metatable / make the infos unusable */
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

/// Copies the given bytes into the array.
//
// @function append
// @tparam GLib.Bytes|ByteArray|string data The data to copy.
static int
bytearray_append(lua_State* L)
{
    bytearray* array = luaL_checkudata(L, 1, LUA_BYTEARRAY);
    gsize size = 0;
    const void* data = NULL;

    switch (lua_type(L, 2)) {
        case LUA_TSTRING: {
            data = lua_tolstring(L, 2, &size);
            break;
        }
        case LUA_TUSERDATA: {
            // TODO: Allow appending `bytearray`

            // Run the incredibly hacky thing to get a usable representation
            // of the userdatum's type.
            // The `._name` field doesn't seem to be available via `lua_getfield`,
            // which what the `luaL_loadstring` is for.
            // And I don't want to go through everything that's required to set up
            // linking against LGI to use their `GType` functions.
            if (luaL_loadstring(L, l_get_type_name) != LUA_OK) {
                return luaL_error(L, "loadstring failed");
            };
            lua_pushvalue(L, 2);
            lua_call(L, 1, 1);
            const char* type = lua_tostring(L, -1);
            lua_pop(L, 2);

            luaL_argcheck(L, !strcmp(type, "GLib.Bytes"), 2, "GLib.Bytes expected");
            GBytes* bytes = lua_touserdata(L, 2);
            data = g_bytes_get_data(bytes, &size);
            break;
        }
        default: {
            lua_pop(L, 1);
            // TODO: Use Lua's string formatting
            char msg[80];
            sprintf(msg, "string or userdata expected, got %s", luaL_typename(L, 2));
            return luaL_argerror(L, 2, msg);
        }
    }

    if (data != NULL && size > 0) {
        g_byte_array_append(array->bytearray, data, size);
    }

    lua_pop(L, 1);

    return 1;
}


static const struct luaL_Reg bytearray_mt [] = {
    { "__len", bytearray_len },
    { "__tostring", bytearray_tostring },
    { "__index", bytearray_index },
    { "__newindex", bytearray_newindex },
    { "__gc", bytearray_gc },
    { "__concat", bytearray_append },
    { "append", bytearray_append },
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
