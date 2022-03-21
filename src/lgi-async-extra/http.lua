---------------------------------------------------------------------------
--- HTTP client library.
--
-- @module http
-- @license GPL v3.0
---------------------------------------------------------------------------

local lgi = require("lgi")
local GLib = lgi.GLib
local Soup = lgi.Soup

---
-- @tfield table METHOD A map of the available HTTP methods
-- @tfield table STATUS_CODE A map of the HTTP status codes
local http = {
    METHOD = {
        -- TODO: Add the rest
        GET = "get",
        POST = "post",
    },
    STATUS_CODE = {
        -- TODO: Add the rest
        OK = 200,
    }
}


--- @type Response
-- @tfield[opt] GLib.SocketAddress|GLib.ProxyAddress address The address of the remote party.
-- @tfield Soup.MessageHeaders headers
-- @tfield string method
-- @tfield table request
-- @tfield Soup.MessageHeaders request.headers
-- @tfield string request.method
local response = {}


local function make_response(request)
    local msg = request.message

    local resp = {
        _private = {
            request = request,
        },
        request = {
            headers = msg:get_request_headers(),
            method = request.options.method,
        },
        method = request.options.method,
        headers = msg:get_response_headers(),
        address = msg:get_remote_address(),
    }

    return setmetatable(resp, { __index = response })
end


--- Reads the response data into memory.
--
-- @since git
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn string
function response:read(cb)
    cb(nil, "")
end


--- Parses the response data as JSON.
--
-- @since git
-- @async
-- @tparam function cb
-- @treturn[opt] string|GLib.Error
-- @treturn table
function response:json(cb)
    if self.headers.content_type ~= "application/json" then
        cb("not json")
    end

    self:read(function(err, data)
        cb(err, {})
    end)
end


--- Requests
-- @section requests

--- Performs a GET request.
--
-- If `options` is of type @{string}, it is treated as `{ uri = <value> }`. I.e. the string is
-- taken as URI parameter.
--
-- @since git
-- @async
-- @tparam string|table options
-- @tparam string options.uri The URI to query.
-- @tparam function cb
-- @treturn[opt] string|GLib.Error
-- @treturn Response
function http.get(options, cb)
    if type(options) == "string" then
        options = { uri = options }
    end

    options.method = http.METHOD.GET
    http.request(options, cb)
end



--- Performs an HTTP request of the given method.
--
-- @since git
-- @async
-- @tparam table options
-- @tparam string options.method The HTTP method. May be on of @{http.METHOD}
-- @tparam string options.uri The URI to query.
-- @tparam Soup.Session options.session A libsoup session to run this request in.
-- @tparam function cb
-- @treturn[opt] string|GLib.Error
-- @treturn Response
function http.request(options, cb)
    -- TODO: Add URI parsing/verification
    local msg = Soup.Message(options.method, options.uri)
    if msg == nil then
        return cb("failed to parse URI")
    end

    local request = {
        options = options,
        message = msg,
    }

    if not options.session then
        options.session = Soup.Session()
    end

    local session = options.session
    session:send_async(msg, GLib.PRIORITY_DEFAULT, nil, function(token)
        local stream, err = session:send_finish(token)
        if err then
            return cb(err)
        end

        request.stream = stream
        cb(nil, make_response(request))
    end)
end


return http
