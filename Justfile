outdir := "out"

doc:
    @mkdir -p "{{outdir}}/doc" "{{outdir}}/lib"
    @sh tools/process_docs.sh "{{outdir}}"
    ldoc --config=doc/config.ld --dir "{{outdir}}/doc" --project lgi-async-extra "{{outdir}}/lib"

make version="scm-1":
    luarocks --local make rocks/lgi-async-extra-{{version}}.rockspec

clean:
    rm -r "{{outdir}}"
