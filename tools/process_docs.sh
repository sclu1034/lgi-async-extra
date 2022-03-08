#!/bin/sh

OUT="$1"
if [ -z "$OUT" ] || [ ! -d "$OUT" ]; then
    echo "No such directory: '$OUT'" >&2
    exit 1
fi

LUA=${LUA:-lua}

# Print the command to run similarly to how Make would do it.
run() {
    echo "$@"
    "$@"
}

find src -iname '*.lua' -or -iname '*.c' -not -path '*/internal/*' | while read -r f; do
    mkdir -p "$(dirname "$OUT/$f")"
    run "$LUA" ./tools/preprocessor.lua "$f" "$OUT/$f"
done
