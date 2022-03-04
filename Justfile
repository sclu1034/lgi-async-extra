outdir := "out"

doc:
    @mkdir -p "{{outdir}}/doc" "{{outdir}}/lib"
    @sh tools/process_docs.sh "{{outdir}}"
    ldoc --config=doc/config.ld --dir "{{outdir}}/doc" --project lgi-async-extra "{{outdir}}/lib"

clean:
    rm -r "{{outdir}}"
