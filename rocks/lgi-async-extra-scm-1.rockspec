package = "lgi-async-extra"
version = "scm-1"
source = {
    url = "git://github.com/sclu1034/lgi-async-extra.git"
}
description = {
    summary = "An asynchronous high(er)-level API wrapper for LGI",
    homepage = "https://github.com/sclu1034/lgi-async-extra",
    license = "GPLv3"
}
dependencies = {
    "lua >= 5.1",
    "lgi",
    "async.lua"
}
build = {
    type = "make",
    build_variables = {
        CFLAGS="$(CFLAGS)",
        LIBFLAG="$(LIBFLAG)",
        LUA_LIBDIR="$(LUA_LIBDIR)",
        LUA_BINDIR="$(LUA_BINDIR)",
        LUA_INCDIR="$(LUA_INCDIR)",
        LUA="$(LUA)",
    },
    install_variables = {
        PREFIX="$(PREFIX)",
        INSTALL_BINDIR="$(BINDIR)",
        INSTALL_LIBDIR="$(LIBDIR)",
        INSTALL_LUADIR="$(LUADIR)",
        INSTALL_CONFDIR="$(CONFDIR)",
    },
    copy_directories = {
        "spec"
    }
}
