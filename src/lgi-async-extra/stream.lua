---------------------------------------------------------------------------
--- Utilities to handle Gio streams.
--
-- @module stream
-- @license GPL v3.0
---------------------------------------------------------------------------

local async = require("async")
local bytearray = require("lgi_async_extra.bytearray")
local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib

local module = {}


--- Closes the stream.
--
-- @since 0.2.0
-- @async
-- @tparam Gio.InputStream stream The stream to close.
-- @tparam function cb
-- @treturn GLib.Error
function module.close(stream, cb)
    stream:close_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
        local _, err = stream:close_finish(token)
        cb(err)
    end)
end


--- Reads the requested amount of bytes from the stream.
--
-- @since 0.2.0
-- @async
-- @tparam Gio.InputStream stream The stream to read data from.
-- @tparam number size The amount of bytes to read.
-- @tparam function cb
-- @treturn GLib.Error
-- @treturn GLib.Bytes
function module.read_bytes(stream, size, cb)
    stream:read_bytes_async(size, GLib.PRIORITY_DEFAULT, nil, function(_, token)
        local bytes, err = stream:read_bytes_finish(token)
        cb(err, bytes)
    end)
end

--- Read the entire stream into memory.
--
-- The caller is responsible for freeing the returned `GBytes`.
--
-- @since 0.2.0
-- @async
-- @tparam Gio.InputStream stream The stream to read data from.
-- @tparam[opt=4096] number buffer_size The size of each chunk to read.
-- @tparam function cb
-- @treturn GLib.Error
-- @treturn GLib.Bytes
function module.read_all(stream, buffer_size, cb)
    if type(buffer_size) == "function" then
        cb = buffer_size
        buffer_size = 4096
    end
    local buffer = bytearray.new()

    local function read_chunk(cb_chunk)
        module.read_bytes(stream, buffer_size, function(err, bytes)
            if bytes then
                buffer:append(bytes)
            end
            cb_chunk(err, bytes)
        end)
    end

    -- When the size of returned bytes is smaller than what we have requested,
    -- we must have reached the end.
    local function check(bytes, cb_check)
        cb_check(nil, bytes == nil or bytes:get_size() < buffer_size)
    end

    async.do_while(read_chunk, check, function(err)
        cb(err, buffer:free_to_bytes())
    end)
end

--- Creates a dummy input stream.
--
-- Gio currently supports asynchronous splicing only between IOStreams, which combine both an input and output stream.
-- To be able to splice from just an output stream to just an input stream, dummy streams can be used to provide
-- the "ignored" side of the pipe.
--
-- See [docs.gtk.org](https://docs.gtk.org/gio/class.MemoryInputStream.html) for additional details.
--
-- @treturn Gio.MemoryInputStream
function module.new_dummy_input()
    return Gio.MemoryInputStream.new()
end


--- Creates a dummy output stream.
--
-- Gio currently supports asynchronous splicing only between IOStreams, which combine both an input and output stream.
-- To be able to splice from just an output stream to just an input stream, dummy streams can be used to provide
-- the "ignored" side of the pipe.
--
-- See [docs.gtk.org](https://docs.gtk.org/gio/class.MemoryOutputStream.html) for additional details.
--
-- @treturn Gio.MemoryOutputStream
function module.new_dummy_output()
    return Gio.MemoryOutputStream.new()
end


--- Combines an input and output stream into a single IOStream.
--
-- Either side may be omitted, in which case a dummy stream is used instead.
--
-- See [docs.gtk.org](https://docs.gtk.org/gio/class.SimpleIOStream.html) for additional details.
--
-- @tparam[opt] Gio.InputStream input_stream
-- @tparam[opt] Gio.OutputStream output_stream
-- @treturn Gio.SimpleIOStream
function module.to_io_stream(input_stream, output_stream)
    input_stream = input_stream or module.new_dummy_input()
    output_stream = output_stream or module.new_dummy_output()
    return Gio.SimpleIOStream.new(input_stream, output_stream)
end

return module
