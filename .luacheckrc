std = "max"

ignore = {
    "431",
    "432"
}

files[".luacheckrc"].std = "+luacheckrc"
files["rocks/*.rockspec"].std = "+rockspec"

files["tests/*_spec.lua"] = {
    std = "+busted",
    globals = {
        "wrap_asserts",
        "run"
    }
}
