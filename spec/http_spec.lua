local assert = require("luassert")
local spy = require("luassert.spy")
local async = require("async")

local http = require("lgi-async-extra.http")

local function pass_data_cb(cb, data)
    return function(err)
        cb(err, data)
    end
end

describe('http', function()
    describe('get', function()
        it('returns proper response', run(function(_, cb)
            local check_response = spy(function(resp, cb)
                wrap_asserts(cb, function()
                    assert.is_table(resp.headers)
                    assert.is_number(resp.status)
                    assert.is_function(resp.read)
                    assert.is_function(resp.json)

                    assert.is_same(http.METHOD.GET, resp.method)
                    assert.is_same(http.STATUS_CODE.OK, resp.status_code)
                    -- Make sure we provide both the canonical upper case name and
                    -- a snake_case name suitable for identifiers.
                    assert.is_string(resp.headers["User-Agent"])
                    assert.is_string(resp.headers.user_agent)
                    assert.is_same(resp.headers["User-Agent"], resp.headers.user_agent)
                end)
            end)

            async.waterfall({
                function(cb)
                    http.get("https://httpbin.org", cb)
                end,
                check_response,
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.is_nil(err)
                    assert.spy(check_response).was_called()
                end)
            end)
        end))

        it('reads json content', run(function(_, cb)
            local check_response = spy(function(resp, cb)
                wrap_asserts(cb, function()
                    assert.is_same(200, resp.status)
                    assert.is_same("application/json", resp.headers.content_type)
                end)
            end)

            local check_data = spy(function(data, cb)
                wrap_asserts(pass_data_cb(cb, data), function()
                    assert.is_table(data)
                    -- HTTPBin echos data about the request.
                    -- We'll use that to verify the JSON parsing.
                    assert.is_table(data.headers)
                    assert.is_string(data.url)
                    assert.is_same("application/json", data.headers.Accept)
                end)
            end)

            async.dag({
                response = function(_, cb)
                    http.get("https://httpbin.org", cb)
                end,
                data = { "response", function(results, cb)
                    local resp = table.unpack(results.response)
                    resp:json(cb)
                end },
                check_response = { "response", function(results, cb)
                    local resp = table.unpack(results.response)
                    check_response(resp, cb)
                end },
                check_data = { "data", function(results, cb)
                    local data = table.unpack(results.data)
                    check_data(data, cb)
                end },
            }, function(err)
                wrap_asserts(cb, err, function()
                    assert.is_nil(err)
                    assert.spy(check_response).was_called()
                    assert.spy(check_data).was_called()
                end)
            end)
        end))
    end)
end)
