PREFIX ?= /usr/local
BUILD_DIR = out

LUA_VERSION ?= 5.3
LUA ?= $(shell command -v lua$(LUA_VERSION))
LUA_BINDIR ?= /usr/bin
# LUA_LIBDIR ?= /usr/lib
LUA_INCDIR ?= /usr/include/lua$(LUA_VERSION)

INSTALL_BINDIR ?= $(PREFIX)/bin
INSTALL_LIBDIR ?= $(PREFIX)/lib/lua/$(LUA_VERSION)
INSTALL_LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)
INSTALL_CONFDIR ?= $(PREFIX)/etc

CC = gcc
PKG_CONFIG ?= $(shell command -v pkg-config)

PKGS = glib-2.0 gobject-2.0 lua$(LUA_VERSION)

CFLAGS ?= -fPIC
LIBFLAG ?= -shared

CCFLAGS ?= $(CFLAGS)
CCFLAGS += -g $(shell $(PKG_CONFIG) --cflags $(PKGS)) -I$(LUA_INCDIR)

LIBS = -L"$(LUA_LIBDIR)" -L$(shell dirname "$(shell $(CC) -print-libgcc-file-name)")
LIBS += $(shell $(PKG_CONFIG) --libs $(PKGS))
OBJS = $(shell find src -type f -iname '*.c' | sed 's/\(.*\)\.c$$/$(BUILD_DIR)\/\1\.so/')

ifdef CI
CHECK_ARGS ?= --formatter TAP
TEST_ARGS ?= --output=TAP
endif

.PHONY: clean doc doc-content doc-styles install test check rock

build: $(OBJS)

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(shell dirname "$@")
	$(CC) -c $(CCFLAGS) $< -o $@

%.so: %.o
	$(CC) $(LIBFLAG) -o $@ $< $(LIBS)

doc-styles:
	@printf "\e[1;97mGenerate stylesheet\e[0m\n"
	sass doc/ldoc.scss $(BUILD_DIR)/doc/ldoc.css

doc-content:
	@mkdir -p "$(BUILD_DIR)/doc" "$(BUILD_DIR)/src"
	@printf "\e[1;97mPreprocess sources\e[0m\n"
	sh tools/process_docs.sh "$(BUILD_DIR)"
	@printf "\e[1;97mGenerate documentation\e[0m\n"
	ldoc --config=doc/config.ld --dir "$(BUILD_DIR)/doc" --project lgi_async_extra "$(BUILD_DIR)/src"

doc: doc-content doc-styles
ifdef CI
	touch "$(BUILD_DIR)/doc/.nojekyll"
endif

clean:
	rm -r out/

install: build doc
	@printf "\e[1;97mInstall C libraries\e[0m\n"
	find $(BUILD_DIR)/src -type f -iname '*.so' | xargs install -vDm 644 -t $(INSTALL_LIBDIR)/lgi_async_extra

	@printf "\e[1;97mInstall Lua libraries\e[0m\n"
	find src/ -type f -iname '*.lua' | xargs install -vDm 644 -t $(INSTALL_LUADIR)/lgi_async_extra

	@printf "\e[1;97mInstall documentation\e[0m\n"
	install -vd $(PREFIX)/share/doc/lgi_async_extra
	cp -vr $(BUILD_DIR)/doc/* $(PREFIX)/share/doc/lgi_async_extra

check:
	find src/ -iname '*.lua' | xargs luacheck $(CHECK_ARGS)

test:
	busted --config-file=.busted.lua --lua=$(LUA) $(TEST_ARGS)

rock:
	luarocks --local --lua-version $(LUA_VERSION) make rocks/lgi-async-extra-scm-1.rockspec
