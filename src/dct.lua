--[[
NOTES:
So I do not think we need to use the weird code loading schemes that people have
used like dofile or loadfile. I think we can use the ledgimate require(modname)
call by just modifying package.path, something like this should work:

-----
local addpath = lfs.writedir() .. "Scripts\\?.lua;"
package.path = package.path .. ";" .. addpath
-----

This will add DCT to the end of module search path and should allow for the
following:

require("dct.init")

----
local addpath = lfs.writedir() .. "Scripts\\?.lua;"
package.path = package.path .. ";" .. addpath
local x = require("dct.init")
x.init()
----

I am pretty sure lfs.writedir() points to your "Saved Games/DCS" directory.

This works but requires the MissionScripting.lua file to be modified to
not sanatize lfs and overwrite 'require' to nil. This seems doable as
GAW already doesn't sanatize the scripting environment, for reasons I do
not know.
--]]

do
    --[[
    -- test and verify the server's environment supports the calls
    -- required by DCT framework
    --]]
    local assertmsg = "DCT requires DCS mission scripting environment to be" ..
                " modified, the file needing to be changed can be found at" ..
                " $DCS_ROOT\Scripts\MissionScripting.lua. Comment out the" ..
                " removal of lfs and io and the setting of 'require' to nil."
    if not lfs or not io or not require then
        assert(false, assertmsg)
    end

    local addpath = lfs.writedir() .. "Scripts\\?.lua;"
    package.path = package.path .. ";" .. addpath
    local x = require("dct.init")
    dctsettings = dctsettings or {}
    x.init(dctsettings)
end
