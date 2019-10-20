--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

local goaltype = {
	["INVALID"] = 0,
	["DAMAGE"]  = 1,
	["MAX"]     = 2,
}

local objtype = {
	["INVALID"] = 0,
	["UNIT"]    = 1,
	["STATIC"]  = 2,
	["GROUP"]   = 3,
	["MAX"]     = 4,
}

local priority = {
	["INVALID"]   = 0,
	["PRIMARY"]   = 1,
	["SECONDARY"] = 2,
	["MAX"]       = 3,
}

local enums = {}
enums.goaltype = goaltype
enums.objtype  = objtype
enums.priority = priority

return enums
