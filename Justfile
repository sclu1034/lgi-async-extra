outdir := "out"

doc:
    @mkdir -p "{{outdir}}/doc" "{{outdir}}/lib"
    @sh tools/process_docs.sh "{{outdir}}"
    ldoc --config=doc/config.ld --dir "{{outdir}}/doc" --project lgi-async-extra "{{outdir}}/lib"

test *ARGS:
    busted --config-file=.busted.lua --helper=tests/_helper.lua {{ARGS}} tests

check *ARGS:
    find lib/ -iname '*.lua' | xargs luacheck {{ARGS}}

make version="scm-1":
    luarocks --local make rocks/lgi-async-extra-{{version}}.rockspec

clean:
    rm -r "{{outdir}}"
