---------------------------------------------------------------------------
--- High level file handling library.
--
-- A file handle can be created through one of the constructor functions. File
-- operations are performed on that handle.
--
-- The API is callback based, so the use of [async.lua](https://github.com/sclu1034/async.lua) for composition is
-- recommended. All callbacks receive an `err` value as first argument, and any non-error return values
-- after that.
-- The `err` value will be `nil` on success, or an error value otherwise. In almost all cases
-- it will be an instance of `GLib.Error`:
--
--    read_non_existent_file(function(err, data)
--        print(err) -- or `print(err.message)`
--        assert(err.domain == Gio.IOErrorEnum)
--        -- Checking the error code against a constant is the recommended way,
--        -- but a bit verbose, due to LGI's mapping.
--        -- See: https://github.com/pavouk/lgi/blob/master/docs/guide.md
--        assert(err.code == Gio.IOErrorEnum[Gio.IOErrorEnum.NOT_FOUND])
--    end)
--
-- Example to write and read-back a file:
--
--    local f = File.new_for_path("/tmp/foo.txt")
--    async.waterfall({
--        function(cb)
--            -- By default, writing replaces any existing content
--            f:write("hello", cb)
--        end,
--        function(cb)
--            -- But we can also append to the file
--            f:write("world", "append", cb)
--        end,
--        function(cb)
--            f:read_all(cb)
--        end,
--    }, function(err, data)
--        print(err)
--        print(data)
--    end)
--
-- @module file
-- @license GPL v3.0
---------------------------------------------------------------------------

local async = require("async")
local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib
local GFile = Gio.File

local stream_utils = require("lgi_async_extra.stream")


local File = {}
local file = {}

--- Constructors
-- @section constructors

--- Create a file handle for the given local path.
--
-- This is a cheap operation, that only creates an in memory representation of the resource location.
-- No I/O will take place until a corresponding method is called on the returned `File` object.
--
-- @tparam string path
-- @treturn File
function file.new_for_path(path)
    local f = GFile.new_for_path(path)
    local ret = {
        _private = {
            f = f,
            path = path,
        }
    }
    return setmetatable(ret, { __index = File  })
end


--- Create a file handle for the given remote URI.
--
-- This is a cheap operation, that only creates an in memory representation of the resource location.
-- No I/O will take place until a corresponding method is called on the returned `File` object.
--
-- @tparam string uri
-- @treturn File
function file.new_for_uri(uri)
    local f = GFile.new_for_uri(uri)
    local ret = {
        _private = {
            f = f,
            path = uri,
        }
    }
    return setmetatable(ret, { __index = File  })
end


--- Create a new file in a directory preferred for temporary storage.
--
-- If `template` is given, it must contain a sequence of six `X`s somewhere in the string, which
-- will replaced by a unique ID to ensure the new file does not overwrite existing ones. The template must not contain
-- any directory components.
-- If `template == nil`, a default value will be used.
--
-- The directory is determined by [g_get_tmp_dir](https://docs.gtk.org/glib/func.get_tmp_dir.html).
--
-- The second return value is a `Gio.FileIOStream`, which contains both an input and output stream to the created
-- file. The caller is responsible for closing these streams.
--
-- The third return value will be an instance of `GLib.Error` if the attempt to create the file failed. If this
-- is not `nil`, attempts to access the other return values will result in undefined behavior.
--
-- See [docs.gtk.org](https://docs.gtk.org/gio/type_func.File.new_tmp.html) for additional details.
--
-- @tparam[opt=".XXXXXX"] string template
-- @treturn File
-- @treturn GIO.FileIOStream
-- @treturn[opt] GLib.Error
function file.new_tmp(template)
    local f, stream, err = GFile.new_tmp(template)
    local ret = {
        _private = {
            f = f,
            template = template,
        }
    }
    return setmetatable(ret, { __index = File  }), stream, err
end

--- @type File

--- Creates a final callback to pass results and clean up the file stream.
--
-- @tparam[opt] string index Index into the `async.dag` results table.
-- @tparam function cb The callback to proxy
-- @treturn function
local function clean_up_stream(index, cb)
    return function(err, results)
        if not results.stream then
            cb(err)
        end

        -- Make sure to always close the stream, even if the read operation failed.
        local stream = table.unpack(results.stream)
        stream_utils.close(stream, function(err_inner)
            local result
            if index and results[index] then
                result = table.unpack(results[index])
            end

            -- Prioritize the outer error (from the read operation), as the inner error (closing the stream) may be
            -- a result of that.
            cb(err or err_inner, result)
        end)
    end
end


--- Get the file's path name.
--
-- The path is guaranteed to be absolute, by may contain unresolved symlinks.
-- However, a path may not exist, in which case `nil` will be returned.
--
-- @treturn[opt] string
function File:get_path()
    return self._private.f:get_path()
end

--- Open a read stream.
--
-- The consumer is responsible for properly closing the stream:
--
--    stream:close_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
--        local _, err = stream:close_finish(token)
--        cb(err)
--    end)
--
-- A [GDataInputStream](https://docs.gtk.org/gio/class.DataInputStream.html) adds additional reading utilities:
--
--    stream = Gio.DataInputStream.new(stream)
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn[opt] Gio.FileInputStream
function File:read_stream(cb)
    local f = self._private.f

    f:read_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
        local stream, err = f:read_finish(token)
        cb(err, stream)
    end)
end


--- Open a write stream.
--
-- Write operations are buffered, so the stream needs to be flushed (or closed)
-- to be sure that changes are written to disk. Especially in `replace` mode,
-- reading before flushing will yield stale content.
--
-- The consumer is responsible for properly closing the stream:
--
--    stream:close_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
--        local _, err = stream:close_finish(token)
--        cb(err)
--    end)
--
-- @async
-- @tparam[opt="replace"] string mode Either `"append"` or `"replace"`.
--  `"replace"` will truncate the file before writing, `"append"` will keep
--  any existing content and add the new data at the end.
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn Gio.FileOutputStream
function File:write_stream(mode, cb)
    local f = self._private.f
    local priority = GLib.PRIORITY_DEFAULT

    if type(mode) == "function" then
        cb = mode
        mode = nil
    end

    if mode == "append" then
        f:append_to_async(
            Gio.FileCreateFlags.NONE,
            priority,
            nil,
            function(_, token)
                local stream, err = f:append_to_finish(token)
                cb(err, stream)
            end
        )
    else
        f:replace_async(
            nil,
            false,
            Gio.FileCreateFlags.NONE,
            priority,
            nil,
            function(_, token)
                local stream, err = f:replace_finish(token)
                cb(err, stream)
            end
        )
    end
end


--- Write the data to the opened file.
--
-- @async
-- @tparam string data The data to write.
-- @tparam[opt="replace"] string mode Either `"append"` or `"replace"`.
--  `"replace"` will truncate the file before writing, `"append"` will keep
--  any existing content and add the new data at the end.
-- @tparam function cb
-- @treturn[opt] GLib.Error
function File:write(data, mode, cb)
    local priority = GLib.PRIORITY_DEFAULT

    if type(mode) == "function" then
        cb = mode
        mode = nil
    end

    async.dag({
        stream = function(_, cb_inner)
            self:write_stream(mode, cb_inner)
        end,
        write = { "stream", function(results, cb_inner)
            local stream = table.unpack(results.stream)

            stream:write_all_async(data, priority, nil, function(_, token)
                local _, _, err = stream:write_all_finish(token)
                cb_inner(err)
            end)
        end },
    }, clean_up_stream(nil, cb))
end


--- Read at most the specified number of bytes from the file.
--
-- If there is not enough data to read, the result may contain less than `size` bytes.
--
-- @since 0.2.0
-- @async
-- @tparam number size The number of bytes to read.
-- @tparam function cb The callback to call when reading finished.
--   Signature: `function(err, data)`
-- @treturn[opt] GLib.Error An instance of `GError` if there was an error,
--   `nil` otherwise.
-- @treturn GLib.Bytes
function File:read_bytes(size, cb)
    local priority = GLib.PRIORITY_DEFAULT

    async.dag({
        stream = function(_, cb_inner)
            self:read_stream(cb_inner)
        end,
        bytes = { "stream", function(results, cb_inner)
            local stream = table.unpack(results.stream)

            stream:read_bytes_async(size, priority, nil, function(_, token)
                local bytes, err = stream:read_bytes_finish(token)
                cb_inner(err, bytes)
            end)
        end },
    }, clean_up_stream("bytes", cb))
end


--- Read the entire file's content into memory.
--
-- Note that this currently only works for files with a known size. Virtual files cannot be read from successfully
-- and will either return an empty string or fail.
--
-- @async
-- @tparam function cb The callback to call when reading finished.
--   Signature: `function(err, data)`
-- @treturn[opt] GLib.Error An instance of `GError` if there was an error,
--   `nil` otherwise.
-- @treturn string A string read from the file.
function File:read_all(cb)
    async.dag({
        stream = function(_, cb_inner)
            self:read_stream(cb_inner)
        end,
        bytes = { "stream", function(results, cb_inner)
            local stream = table.unpack(results.stream)
            stream_utils.read_all(stream, cb_inner)
        end },
    }, clean_up_stream("bytes", cb))
end


--- Read a line from the file.
--
-- Inefficient when reading lines repeatedly from the same file.
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error An instance of `GError` if there was an error,
--   `nil` otherwise.
-- @treturn[opt] string A string read from the file,
--   or `nil` if the end was reached.
function File:read_line(cb)
    local priority = GLib.PRIORITY_DEFAULT

    async.dag({
        stream = function(_, cb_inner)
            self:read_stream(cb_inner)
        end,
        line = { "stream", function(results, cb_inner)
            local stream = table.unpack(results.stream)

            stream = Gio.DataInputStream.new(stream)
            stream:read_line_async(priority, nil, function(_, token)
                local line, _, err = stream:read_line_finish(token)
                cb_inner(err, line)
            end)
        end },
    }, clean_up_stream("line", cb))
end


--- Asynchronously iterate over the file line by line.
--
-- This function opens a read stream and starts reading the file line-wise,
-- asynchronously. For every line read, the given `iteratee` is called with any
-- potential error, the line's content (without the trailing newline)
-- and a callback function. The callback must always be called to ensure the
-- file handle is cleaned up eventually. The expected signature for the callback
-- is `cb(err, stop)`. If `err ~= nil` or a value for `stop` is given, iteration stops
-- immediately and `cb` will be called.
--
-- @tparam function iteratee Function to call per line in the file. Signature:
--   `function(err, line, cb)`
-- @tparam function cb Function to call when iteration has stopped.
--   Signature: `function(err)`.
function File:iterate_lines(iteratee, cb)
    local priority = GLib.PRIORITY_DEFAULT

    async.dag({
        stream = function(_, cb_inner)
            self:read_stream(cb_inner)
        end,
        lines = { "stream", function(results, cb_inner)
            local stream = table.unpack(results.stream)
            stream = Gio.DataInputStream.new(stream)

            local function read_line(cb_line)
                stream:read_line_async(priority, nil, function(_, token)
                    local line, _, err = stream:read_line_finish(token)

                    iteratee(err, line, function(err, stop)
                        cb_line(err, stop or false, line)
                    end)
                end)
            end

            local function check(stop, line, cb_check)
                if type(line) == "function" then
                    cb_check = line
                    line = nil
                end

                local continue = (not stop) and (line ~= nil)
                cb_check(nil, continue)
            end

            async.do_while(read_line, check, function(err)
                cb_inner(err)
            end)
        end },
    }, clean_up_stream(nil, cb))
end


--- Move the file to a new location.
--
-- Requires GLib version 2.71.2 or newer (2022-02-15).
--
-- @async
-- @tparam string destination New path to move to
-- @tparam function cb
-- @treturn[opt] GLib.Error
function File:move(destination, cb)
    local f = self._private.f
    local priority = GLib.PRIORITY_DEFAULT

    destination = GFile.new_for_path(destination)

    f:move_async(destination, 0, priority, nil, nil, function(_, token)
        local _, err = f:move_finish(token)
        cb(err)
    end)
end


--- Delete the file.
--
-- This has the same semantics as POSIX `unlink()`, i.e. the link at the given
-- path is removed. If it was the last link to the file, the disk space occupied
-- by that file is freed as well.
--
-- Empty directories are deleted by this as well.
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
function File:delete(cb)
    local f = self._private.f
    local priority = GLib.PRIORITY_DEFAULT

    f:delete_async(priority, nil, function(_, token)
        local _, err = f:delete_finish(token)
        cb(err)
    end)
end


--- Move the file to trash.
--
-- Support for this depends on the platform and file system. If unsupported
-- an error of type `Gio.IOErrorEnum.NOT_SUPPORTED` will be returned.
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
function File:trash(cb)
    local f = self._private.f
    local priority = GLib.PRIORITY_DEFAULT

    f:trash_async(priority, nil, function(_, token)
        local _, err = f:trash_finish(token)
        cb(err)
    end)
end


--- Query file information.
--
-- This can be used to query for any file info attribute supported by GIO.
-- The attribute parameter may either be plain string, such as `"standard::size"`, a wildcard `"standard::*"` or
-- a list of both `"standard::*,owner::user"`.
--
-- GIO also offers constants for these attribute values, which can be found by querying the GIO docs for
-- `G_FILE_ATTRIBUTE_*` constants:
-- [https://docs.gtk.org/gio/index.html?q=G_FILE_ATTRIBUTE_](https://docs.gtk.org/gio/index.html?q=G_FILE_ATTRIBUTE_)
--
-- See [docs.gtk.org](https://docs.gtk.org/gio/method.File.query_info.html) for additional details.
--
-- @todo Document the conversion from GIO's attributes to what LGI expects.
-- @async
-- @tparam string attribute The GIO file info attribute to query for.
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn[opt] Gio.FileInfo
function File:query_info(attribute, cb)
    local f = self._private.f
    local priority = GLib.PRIORITY_DEFAULT

    f:query_info_async(attribute, 0, priority, nil, function(_, token)
        local info, err = f:query_info_finish(token)
        cb(err, info)
    end)
end


--- Check if the file exists.
--
-- Keep in mind that checking for existence before reading or writing a file is
-- subject to race conditions.
-- An external process may still alter a file between those two operations.
--
-- Also note that, due to limitations in GLib, this method cannot distinguish
-- between a file that is actually absent and a file that the user has no access
-- to.
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn boolean `true` if the file exists on disk
function File:exists(cb)
    self:query_info("standard::type", function (err)
        if err then
            -- An error of "not found" is actually an expected outcome, so
            -- we hide the error.
            if err.code == Gio.IOErrorEnum[Gio.IOErrorEnum.NOT_FOUND] then
                cb(nil, false)
            else
                cb(err, false)
            end
        else
            cb(nil, true)
        end
    end)
end


--- Query the size of the file.
--
-- Note that due to limitations in GLib, this will return `0` for files
-- that the user has no access to.
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn[opt] number
function File:size(cb)
    self:query_info("standard::size", function (err, info)
        -- For some reason, the bindings return a float for a byte size
        cb(err, info and math.floor(info:get_size()))
    end)
end


--- Query the type of the file.
--
-- Common scenarios would be to compare this against `Gio.FileType`.
--
-- Note that due to limitations in GLib, this will return `Gio.FileType.UNKNOWN` for files
-- that the user has no access to.
--
-- @usage
--    f:type(function(err, type)
--        if err then return cb(err) end
--        local is_dir = type == Gio.FileType.DIRECTORY
--        local is_link = type == Gio.FileType.SYMBOLIC_LINK
--        local is_file = type == Gio.FileType.REGULAR
--        -- get a string representation
--        print(Gio.FileType[type])
--    end)
--
-- @async
-- @tparam function cb
-- @treturn[opt] GLib.Error
-- @treturn[opt] Gio.FileType
function File:type(cb)
    self:query_info("standard::type", function (err, info)
        cb(err, info and Gio.FileType[info:get_file_type()])
    end)
end

return file
