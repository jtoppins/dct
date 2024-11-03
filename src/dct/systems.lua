-- SPDX-License-Identifier: LGPL-3.0

--- DCT Systems. Various systems that operate at the theater level to
-- manage the game and its flow.
-- @module dct.systems
-- @alias __sys

require("lfs")
require("libs")

local __sys = {}

local requireroot = "dct.systems."
local syspath = libs.utils.join_paths(dct.modpath, "lua", "dct", "systems")

for file in lfs.dir(syspath) do
	local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

	if st then
		local c = require(requireroot..cap1)
		if c.enabled == nil then
			c.enabled = false
		end
		__sys[c.__clsname] = c
	end
end

local __sys_mt = {}
__sys_mt.__index = {}
function __sys_mt.__newindex()
	error("cannot modify the dct.systems table")
end

--- Check if a system is enabled.
-- @alias dct.systems.isEnabled
-- @tparam reference system a reference to a System class.
-- @treturn bool true if the system should be enabled.
function __sys_mt.__index.isEnabled(system)
	if system ~= nil and system.enabled == true then
		return true
	end
	return false
end

--- Set if the system should be enabled when a Theater instance is
-- created.
-- @alias dct.systems.setEnabled
-- @tparam reference system a reference to a System class.
-- @tparam bool enable true to turn the system on, false to disable
function __sys_mt.__index.setEnabled(system, enable)
	if system == nil then
		return
	end
	system.enabled = enable
end

--- Iterate over all System classes that are enabled.
-- @alias dct.systems.iterateEnabled
function __sys_mt.__index.iterateEnabled()
	local function fnext(state, index)
		local idx = index
		local system
		repeat
			idx, system = next(state, idx)
			if system == nil then
				return nil
			end
		until(system.enabled == true)
		return idx, system
	end
	return fnext, __sys, nil
end

setmetatable(__sys, __sys_mt)

return __sys
