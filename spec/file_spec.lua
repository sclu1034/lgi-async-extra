local assert = require("luassert")
local spy = require("luassert.spy")
local async = require("async")

local File = require("lgi-async-extra.file")

describe('file', function()
    describe('exists', function()
        it('returns false for non-existant file', run(function (_, cb)
            local f = File.new_for_path("/this_should_not.exist")

            f:exists(function(err, exists)
                wrap_asserts(cb, err, function()
                    assert.is_false(exists)
                    assert.is_function(cb)
                end)
            end)
        end))

        it('handles file deletion', run(function(_, cb)
            local f = File.new_tmp()

            local check_exists = spy(function(exists, cb)
                wrap_asserts(cb, function()
                    assert.is_true(exists)
                    assert.is_function(cb)
                end)
            end)

            local check_removed = spy(function(exists, cb)
                wrap_asserts(cb, function()
                    assert.is_false(exists)
                    assert.is_function(cb)
                end)
            end)

            async.waterfall({
                async.callback(f, f.exists),
                check_exists,
                async.callback(f, f.delete),
                async.callback(f, f.exists),
                check_removed,
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.spy(check_exists).was_called()
                    assert.spy(check_removed).was_called()
                end)
            end)
        end))
    end)

    it('writes and reads', run(function(f, cb)
        local str = "Hello, World!"

        local check_read_empty = spy(function(cb)
            wrap_asserts(cb, function()
                assert.is_function(cb)
            end)
        end)

        local check_read_data = spy(function(data, cb)
            wrap_asserts(cb, function()
                assert.is_same(str, data)
                assert.is_function(cb)
            end)
        end)

        async.waterfall({
            async.callback(f, f.read_string),
            check_read_empty,
            async.callback(f, f.write, str, "replace"),
            async.callback(f, f.read_string),
            check_read_data,
        }, function(err)
            wrap_asserts(cb, err, function()
                assert.spy(check_read_empty).was_called()
                assert.spy(check_read_data).was_called()
            end)
        end)
    end))

    describe('read_bytes', function()
        it('returns empty bytes for empty file', run(function(f, cb)
            f:read_bytes(4096, function(err, bytes)
                wrap_asserts(cb, err, function()
                    assert.is_nil(err)
                    assert.is_userdata(bytes)
                    assert.is_same(0, #bytes)
                end)
            end)
        end))

        it('reads the specified number of bytes, if possible', run(function(f, cb)
            local data = "Hello, world!"

            async.waterfall({
                async.callback(f, f.write, data, "replace"),
                function(cb)
                    f:read_bytes(#data, function(err, bytes)
                        wrap_asserts(cb, err, function()
                            assert.is_nil(err)
                            assert.is_userdata(bytes)
                            assert.is_same(#data, #bytes)
                            assert.is_same(data, bytes:get_data())
                        end)
                    end)
                end,
            }, cb)
        end))

        it('reads less if not enough data', run(function(f, cb)
            local BUFFER_SIZE = 4096
            local data = "Hello, world!"

            async.waterfall({
                async.callback(f, f.write, data, "replace"),
                function(cb)
                    f:read_bytes(BUFFER_SIZE, function(err, bytes)
                        wrap_asserts(cb, err, function()
                            assert.is_nil(err)
                            assert.is_userdata(bytes)
                            assert(#bytes < BUFFER_SIZE)
                            assert.is_same(#data, #bytes)
                            assert.is_same(data, bytes:get_data())
                        end)
                    end)
                end,
            }, cb)
        end))
    end)

    describe('read_string', function()
        it('returns nil for empty file', run(function(f, cb)
            f:read_string(function(err, str)
                wrap_asserts(cb, err, function()
                    assert.is_nil(err)
                    assert.is_nil(str)
                end)
            end)
        end))

        it('reads a short file, less than buffer size', run(function(f, cb)
            local data = "Hello, world!"

            async.waterfall({
                async.callback(f, f.write, data, "replace"),
                function(cb)
                    f:read_string(function(err, str)
                        wrap_asserts(cb, err, function()
                            assert.is_nil(err)
                            assert.is_string(str)
                            assert.is_same(data, str)
                        end)
                    end)
                end,
            }, cb)
        end))

        it('reads a long file', run(function(f, cb)
            local data = {}
            for _ = 1, 1000 do
                table.insert(data, "Hello, world!")
            end
            data = table.concat(data, "\n")

            async.waterfall({
                async.callback(f, f.write, data, "replace"),
                function(cb)
                    f:read_string(function(err, str)
                        wrap_asserts(cb, err, function()
                            assert.is_nil(err)
                            assert.is_string(str)
                            assert.is_same(data, str)
                        end)
                    end)
                end,
            }, cb)
        end))

        it('reads virtual files', run(function(_, cb)
            local f = File.new_for_path("/proc/meminfo")

            local check_read_string = spy(function(data, cb)
                wrap_asserts(cb, function()
                    assert.is_string(data)
                    assert.is_not_nil(data:match("SwapTotal"))
                end)
            end)

            async.waterfall({
                async.callback(f, f.read_string),
                check_read_string,
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.spy(check_read_string).was_called()
                end)
            end)
        end))
    end)

    describe('read_line', function()
        it('returns nil for empty file', run(function(f, cb)
            f:read_line(function(err, line)
                wrap_asserts(cb, err, function()
                    assert.is_nil(err)
                    assert.is_nil(line)
                end)
            end)
        end))

        it('always reads the first line', run(function(f, cb)
            local lines = { "Hello, World!", "Second Line" }

            local check_line = spy(function(data, cb)
                wrap_asserts(cb, function()
                    assert.is_same(lines[1], data)
                    assert.is_function(cb)
                end)
            end)

            async.waterfall({
                async.callback(f, f.write, table.concat(lines, "\n"), "replace"),
                async.callback(f, f.read_line),
                check_line,
                async.callback(f, f.read_line),
                check_line,
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.spy(check_line).was_called(2)
                end)
            end)
        end))

        it('reads virtual files', run(function(_, cb)
            local f = File.new_for_path("/proc/meminfo")

            f:read_line(function(err, line)
                wrap_asserts(cb, err, function()
                    assert.is_string(line)
                    assert.is_same("MemTotal", line:match("MemTotal"))
                end)
            end)
        end))
    end)

    describe('iterate_lines', function()
        it('iterates over lines', run(function(f, cb)
            local lines = { "Hello, World!", "Second Line" }
            local count = 1

            local check_line = spy(function(err, line, cb)
                if type(line) == "function" then
                    cb = line
                    line = nil
                end

                wrap_asserts(cb, err, function()
                    if count > 2 then
                        assert.is_nil(line)
                    else
                        assert.is_same(lines[count], line)
                    end
                    assert.is_function(cb)
                    count = count + 1
                end)
            end)

            async.waterfall({
                async.callback(f, f.write, table.concat(lines, "\n"), "replace"),
                function(cb)
                    f:iterate_lines(check_line, cb)
                end,
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.spy(check_line).was_called(3)
                end)
            end)
        end))
    end)

    -- TODO: Create test case for `f:move()`. Requires GLib 2.71.2
end)
