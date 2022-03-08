local assert = require("luassert")
local spy = require("luassert.spy")
local async = require("async")

local bytearray = require("lgi_async_extra.bytearray")

describe('bytearray', function()
    it('can be constructed', function()
        assert.is_not_nil(bytearray.new())
    end)
end)
