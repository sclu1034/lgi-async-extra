---------------------------------------------------------------------------
--- File system and directory operation utilities.
--
-- @module filesystem
-- @license GPL v3.0
---------------------------------------------------------------------------

local async = require("async")
local lgi = require("lgi")
local GLib = lgi.GLib
local Gio = lgi.Gio
local File = require("lgi-async-extra.file")


local filesystem = {}


local function file_arg(arg)
    if type(arg) == "string" then
        return Gio.File.new_for_path(arg)
    elseif File.is_instance(arg) then
        return arg._private.f
    else
        return arg
    end
end


--- Creates a directory at the given path.
--
-- This only creates the child directory of the immediate parent of `path`. If the parent
-- directory doesn't exist, this operation will fail.
--
-- @since 0.2.0
-- @async
-- @tparam string|File|Gio.File path
-- @tparam function cb
-- @treturn[opt] GLib.Error
function filesystem.make_directory(path, cb)
    local f = file_arg(path)

    f:make_directory_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
        local _, err = f:make_directory_finish(token)
        cb(err)
    end)
end


--- Iterates the contents of a directory.
--
-- The `iteratee` callback is called once for every entry in the given directory, passing a
-- [Gio.FileInfo](https://docs.gtk.org/gio/class.FileInfo.html) as argument.
-- It's callback argument only expects a single error parameter.
--
-- On error, either within the iteration or passed by `iteratee`, iteration is aborted and
-- the final callback is called.
--
-- See @{file:query_info} and [g_file_query_info](https://docs.gtk.org/gio/method.File.query_info.html) for
-- information on the `attributes` parameter.
--
-- @since 0.2.0
-- @async
-- @tparam string|File|Gio.File dir The directory to query contents for.
-- @tparam function iteratee The iterator function that will be called for each entry.
-- The function will be called with a `Gio.FileInfo` and a callback: `function(info, cb)`.
-- @tparam string attributes The attributes to query.
-- @tparam function cb
-- @tresult[opt] GLib.Error
function filesystem.iterate_contents(dir, iteratee, attributes, cb)
    if type(attributes) == "function" then
        cb = attributes
        attributes = "standard::type"
    end

    local priority = GLib.PRIORITY_DEFAULT
    local f = file_arg(dir)

    async.dag({
        enumerator = function(_, cb)
            f:enumerate_children_async(attributes, Gio.FileQueryInfoFlags.NONE, priority, nil, function(_, token)
                local enumerator, err = f:enumerate_children_finish(token)
                cb(err, enumerator)
            end)
        end,
        iterate = { "enumerator", function(results, cb)
            local enumerator = table.unpack(results.enumerator)

            -- `next_files_async` reports errors in a two-step system. In the event of an error,
            -- the ongoing call will still succeed and report all files that had been queried
            -- successfully. The function then expects to be called again, to return the error.
            -- TODO: Investigate the benefits of querying multiple files at once.

            local function iterate(cb_iterate)
                enumerator:next_files_async(1, priority, nil, function(_, token)
                    local infos, err = enumerator:next_files_finish(token)

                    if err or #infos == 0 then
                        return cb_iterate(err, infos)
                    end

                    iteratee(infos[1], function(err)
                        cb_iterate(err, infos)
                    end)
                end)
            end

            local function check(infos, cb_check)
                cb_check(nil, #infos > 0)
            end

            async.do_while(iterate, check, function(err)
                cb(err)
            end)
        end },
    }, function(err, results)
        local enumerator = table.unpack(results.enumerator)

        enumerator:close_async(priority, nil, function(_, token)
            local _, err_inner = enumerator:close_finish(token)

            -- If the enumerator was already closed, we can ignore the error.
            if err and err.code == Gio.IOErrorEnum[Gio.IOErrorEnum.CLOSED] then
                err_inner = nil
            end

            cb(err or err_inner)
        end)
    end)
end


return filesystem
