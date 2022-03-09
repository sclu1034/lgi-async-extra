local assert = require("luassert")
local spy = require("luassert.spy")
local lgi = require("lgi")
local GLib = lgi.GLib

local bytearray = require("lgi_async_extra.bytearray")

describe('bytearray', function()
    local buf

    before_each(function()
        buf = bytearray.new()
    end)

    it('can be constructed', function()
        assert.is_userdata(buf)
    end)

    it('can receive string data', function()
        local data = "foo"
        assert.is_same(0, #buf)

        buf:append(data)
        assert.is_same(#data, #buf)

        buf = buf .. data
        assert.is_userdata(buf)
        assert.is_same(#data * 2, #buf)
        assert.is_same(data .. data, tostring(buf))
    end)

    it('can receive GBytes data', function()
        local data = "foo"
        local bytes = GLib.Bytes.new("foo")
        assert.is_same(0, #buf)

        buf:append(bytes)
        assert.is_same(#data, #buf)

        buf = buf .. bytes
        assert.is_userdata(buf)
        assert.is_same(#data * 2, #buf)
        assert.is_same(data .. data, tostring(buf))
    end)

    it('can be converted to a string', function()
        local data = "Hello, World!"
        buf:append(data)

        assert.is_same(#data, #buf)
        assert.is_same(data, tostring(buf))
    end)
end)
