---------------------------------------------------------------------------
--- File system and directory operation utilities.
--
-- @module filesystem
-- @license GPL v3.0
---------------------------------------------------------------------------

local lgi = require("lgi")
local GLib = lgi.GLib
local Gio = lgi.Gio
local File = require("lgi-async-extra.file")


local filesystem = {}


--- Creates a directory at the given path
--
-- This only creates the child directory of the immediate parent of `path`. If the parent
-- directory doesn't exist, this operation will fail.
--
-- @since 0.2.0
-- @async
-- @tparam string|Gio.File|file path
-- @tparam function cb
-- @treturn[opt] GLib.Error
function filesystem.make_directory(path, cb)
    local f
    if type(path) == "string" then
        f = Gio.File.new_for_path(path)
    elseif Gio.File:is_type_of(path) then
        f = path
    elseif File.is_instance(path) then
        f = path._private.f
    end

    f:make_directory_async(GLib.PRIORITY_DEFAULT, nil, function(_, token)
        local _, err = f:make_directory_finish(token)
        cb(err)
    end)
end


return filesystem
