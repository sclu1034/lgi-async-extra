---------------------------------------------------------------------------
--- Utilities to handle Gio streams.
--
-- @module stream
-- @license GPL-v3-or-later
---------------------------------------------------------------------------

local lgi = require("lgi")
local Gio = lgi.Gio

local stream = {}


function stream.new_dummy_input()
    return Gio.MemoryInputStream.new()
end


--- Creates an output stream
function stream.new_dummy_output()
    return Gio.MemoryOutputStream.new()
end


function stream.to_io_stream(input_stream, output_stream)
    input_stream = input_stream or stream.new_dummy_input()
    output_stream = output_stream or stream.new_dummy_output()
    return Gio.SimpleIOStream.new(input_stream, output_stream)
end

return stream
