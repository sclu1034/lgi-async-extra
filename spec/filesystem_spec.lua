local assert = require("luassert")
local spy = require("luassert.spy")
local async = require("async")

local lgi = require("lgi")
local GLib = lgi.GLib
local Gio = lgi.Gio
local File = require("lgi-async-extra.file")
local fs = require("lgi-async-extra.filesystem")

describe('filesystem', function()
    describe('make_directory', function()
        local path = string.format("%s/lgi-async-extra_tests", GLib.get_tmp_dir())

        it('creates the directory', run(function(cb)
            local f = File.new_for_path(path)

            local check_not_exists = spy(function(exists, cb)
                wrap_asserts(cb, function()
                    assert.is_false(exists)
                    assert.is_function(cb)
                end)
            end)

            local check_is_directory = spy(function(info, cb)
                wrap_asserts(cb, function()
                    assert.is_same(Gio.FileType.DIRECTORY, info)
                    assert.is_function(cb)
                end)
            end)

            async.waterfall({
                async.callback(f, f.exists),
                check_not_exists,
                async.callback(f, fs.make_directory),
                async.callback(f, f.type),
                check_is_directory,
            }, function(err)
                f:delete(function(err_inner)
                    cb(err or err_inner)
                end)
            end)
        end))

        it('accepts strings', run(function(cb)
            fs.make_directory(path, function(err)
                File.new_for_path(path):delete(function(err_inner)
                    wrap_asserts(cb, err or err_inner, function()
                        assert.is_nil(err)
                        assert.is_nil(err_inner)
                    end)
                end)
            end)
        end))

        it('accepts lgi-async-extra File', run(function(cb)
            local f = File.new_for_path(path)

            fs.make_directory(f, function(err)
                f:delete(function(err_inner)
                    wrap_asserts(cb, err or err_inner, function()
                        assert.is_nil(err)
                        assert.is_nil(err_inner)
                    end)
                end)
            end)
        end))

        it('accepts Gio.File', run(function(cb)
            local f = Gio.File.new_for_path(path)

            fs.make_directory(f, function(err)
                File.new_for_path(path):delete(function(err_inner)
                    wrap_asserts(cb, err or err_inner, function()
                        assert.is_nil(err)
                        assert.is_nil(err_inner)
                    end)
                end)
            end)
        end))

        it('fails when parent doesn\'t exist', run(function(cb)
            local path = string.format("%s/lgi-async-extra_test_make_directory/inner", GLib.get_tmp_dir())

            fs.make_directory(path, function(err)
                wrap_asserts(cb, function()
                    assert.is_not_nil(err)
                    assert.is_same(Gio.IOErrorEnum, err.domain)
                    assert.is_same(Gio.IOErrorEnum[Gio.IOErrorEnum.NOT_FOUND], err.code)
                end)
            end)
        end))
    end)

    describe('iterate_contents', function()
        it('finds all child entries', run(function(cb)
            local dir = string.format("%s/lgi-async-extra_test_iterate_contents", GLib.get_tmp_dir())
            local files = {
                File.new_for_path(string.format("%s/1", dir)),
                File.new_for_path(string.format("%s/2", dir)),
                File.new_for_path(string.format("%s/3", dir)),
            }

            async.waterfall({
                function(cb)
                    fs.make_directory(dir, cb)
                end,
                function(cb)
                    async.all({
                        function(cb) files[1]:write("1", cb) end,
                        function(cb) files[2]:write("2", cb) end,
                        function(cb) files[3]:write("3", cb) end,
                    }, cb)
                end,
                function(_, cb)
                    local found = {}

                    local iteratee = spy(function(info, cb)
                        wrap_asserts(cb, function()
                            assert.is_function(cb)
                            assert.is_not_nil(info)
                            assert(Gio.FileInfo:is_type_of(info))
                            found[info:get_name()] = true
                            assert.is_same(Gio.FileType[Gio.FileType.REGULAR], info:get_file_type())
                        end)
                    end)

                    fs.iterate_contents(dir, iteratee, function(err)
                        wrap_asserts(cb, err, function()
                            assert.spy(iteratee).was_called(3)
                            assert.is_same({ ["1"] = true, ["2"] = true, ["3"] = true }, found)
                        end)
                    end)
                end,
            }, function(err)
                async.waterfall({
                    function(cb) files[1]:delete(cb) end,
                    function(cb) files[2]:delete(cb) end,
                    function(cb) files[3]:delete(cb) end,
                    function(cb) File.new_for_path(dir):delete(cb) end,
                }, function(err_inner)
                    cb(err or err_inner)
                end)
            end)
        end))
    end)
end)
