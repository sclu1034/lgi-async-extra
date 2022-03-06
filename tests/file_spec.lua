local assert = require("luassert")
local spy = require("luassert.spy")
local async = require("async")

local File = require("lgi-async-extra.file")

describe('file', function()
    it('exists', run(function(cb)
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

    it('writes and reads', run(function(cb)
        local f = File.new_tmp()
        local str = "Hello, World!"

        local check_read_empty = spy(function(data, cb)
            wrap_asserts(cb, function()
                assert.is_same("", data)
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
            async.callback(f, f.read_all),
            check_read_empty,
            async.callback(f, f.write, str, "replace"),
            async.callback(f, f.read_all),
            check_read_data,
            async.callback(f, f.delete),
        }, function(err)
            wrap_asserts(cb, err, function()
                assert.spy(check_read_empty).was_called()
                assert.spy(check_read_data).was_called()
            end)
        end)
    end))

    it('reads a line', run(function(cb)
        local f = File.new_tmp()
        local lines = { "Hello, World!", "Second Line" }

        local check_read_empty = spy(function(cb)
            wrap_asserts(cb, function()
                assert.is_function(cb)
            end)
        end)

        local check_line = spy(function(data, cb)
            wrap_asserts(cb, function()
                assert.is_same(lines[1], data)
                assert.is_function(cb)
            end)
        end)

        async.waterfall({
            async.callback(f, f.read_line),
            check_read_empty,
            async.callback(f, f.write, table.concat(lines, "\n"), "replace"),
            async.callback(f, f.read_line),
            check_line,
            async.callback(f, f.read_line),
            check_line,
            async.callback(f, f.delete),
        }, function(err)
            wrap_asserts(cb, err, function()
                assert.spy(check_read_empty).was_called()
                assert.spy(check_line).was_called(2)
            end)
        end)
    end))

    it('iterates over lines', run(function(cb)
        local f = File.new_tmp()
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
                f:read_lines(check_line, cb)
            end,
            async.callback(f, f.delete),
        }, function(err)
            wrap_asserts(cb, err, function()
                assert.spy(check_line).was_called(3)
            end)
        end)
    end))

    -- TODO: Create test case for `f:move()`. Requires GLib 2.58
end)
