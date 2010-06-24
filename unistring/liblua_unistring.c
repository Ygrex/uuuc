#include <lua.h>
#include <lauxlib.h>
#include <unistr.h>

static int l_u8_strlen(lua_State *L) {
	const uint8_t *s = luaL_checkstring(L, 1);
	lua_pushnumber(L, u8_strlen(s));
	return 1;
}

static int l_u8_mbsnlen(lua_State *L) {
	const uint8_t *s = luaL_checkstring(L, 1);
	const size_t l = luaL_checknumber(L, 2);
	lua_pushnumber(L, u8_mbsnlen(s, l));
	return 1;
}

static int l_u8_strwidth(lua_State *L) {
	const uint8_t *s = luaL_checkstring(L, 1);
	const uint8_t *e = luaL_checkstring(L, 2);
	lua_pushinteger(L, u8_strwidth(s, e));
	return 1;
}

static int l_u8_mblen(lua_State *L) {
	const uint8_t *s = luaL_checkstring(L, 1);
	const size_t n = luaL_checknumber(L, 2);
	lua_pushinteger(L, u8_mblen(s, n));
	return 1;
}

static const struct luaL_reg liblua_unistring [] = {
	{"u8_strlen", l_u8_strlen},
	{"u8_mbsnlen", l_u8_mbsnlen},
	{"u8_strwidth", l_u8_strwidth},
	{"u8_mblen", l_u8_mblen},
	{NULL, NULL}
};

int luaopen_liblua_unistring(lua_State *L) {
	luaL_openlib(L, "unistring", liblua_unistring, 0);
	return 1;
}

