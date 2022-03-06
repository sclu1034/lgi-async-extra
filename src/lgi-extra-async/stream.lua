---------------------------------------------------------------------------
--- Utilities to handle Gio streams.
--
-- @module stream
-- @license GPL v3.0
---------------------------------------------------------------------------

local lgi = require("lgi")
local Gio = lgi.Gio

local stream = {}


--- Creates a dummy input stream.
--
-- Gio currently supports asynchronous splicing only between IOStreams, which combine both an input and output stream.
-- To be able to splice from just an output stream to just an input stream, dummy streams can be used to provide
-- the "ignored" side of the pipe.
--
-- See: [`Gio.MemoryInputStream`](https://docs.gtk.org/gio/class.MemoryInputStream.html)
--
-- @treturn Gio.MemoryInputStream
function stream.new_dummy_input()
    return Gio.MemoryInputStream.new()
end


--- Creates a dummy output stream.
--
-- Gio currently supports asynchronous splicing only between IOStreams, which combine both an input and output stream.
-- To be able to splice from just an output stream to just an input stream, dummy streams can be used to provide
-- the "ignored" side of the pipe.
--
-- See: [`Gio.MemoryOutputStream`](https://docs.gtk.org/gio/class.MemoryOutputStream.html)
--
-- @treturn Gio.MemoryOutputStream
function stream.new_dummy_output()
    return Gio.MemoryOutputStream.new()
end


--- Combines an input and output stream into a single IOStream.
--
-- Either side may be omitted, in which case a dummy stream is used instead.
--
-- See: [`Gio.SimpleIOStream`](https://docs.gtk.org/gio/class.SimpleIOStream.html)
--
-- @tparam ?Gio.InputStream input_stream
-- @tparam ?Gio.OutputStream output_stream
-- @treturn Gio.SimpleIOStream
function stream.to_io_stream(input_stream, output_stream)
    input_stream = input_stream or stream.new_dummy_input()
    output_stream = output_stream or stream.new_dummy_output()
    return Gio.SimpleIOStream.new(input_stream, output_stream)
end

return stream
