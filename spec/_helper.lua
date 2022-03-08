local lgi = require("lgi")
local GLib = lgi.GLib


-- Runs a test function inside a GLib loop, to drive asynchronous operations.
-- Busted itself cannot currently do this.
function run(timeout, fn)
    if type(timeout) == "function" then
        fn = timeout
        timeout = 5000
    else
        timeout = timeout or 5000
    end

    return function()
        local loop = GLib.MainLoop()
        local err

        GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
            fn(function(e)
                if e then
                    err = e
                end

                loop:quit()
            end)
        end)

        GLib.timeout_add(GLib.PRIORITY_DEFAULT, timeout, function()
            err = string.format("Test did not finish within %d seconds. Check for GLib/LGI messages", timeout / 1000)
            loop:quit()
        end)

        loop:run()

        if err then
            error(err)
        end
    end
end


-- Wraps a functions with `assert`s to relay errors to a callback.
-- For convenience, the `err` parameter can be used to shortcurcuit on a caller error.
--
-- The `run` helper can then catch the error and print it.
function wrap_asserts(cb, err, fn)
    if type(err) == "function" then
        fn = err
        err = nil
    end

    if err then
        return cb(err)
    end

    local ok, err = pcall(fn)
    if ok then
        cb(nil)
    else
        cb(debug.traceback(err.message .. "\n", 2))
    end
end
