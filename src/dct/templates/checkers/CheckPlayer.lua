--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")


--- @class CheckPlayer
local CheckPlayer = class("CheckPlayer", Check)
function CheckPlayer:__init()
	Check.__init(self, "Player", {
		["groupId"] = {
			["nodoc"] = true,
			["type"] = Check.valuetype.INT,
			["description"] = "group ID of the player group",
		},
		["parking"] = {
			["nodoc"] = true,
			["default"] = false,
			["type"] = Check.valuetype.INT,
			["description"] = "The parking id",
		},
		["airbase"] = {
			["nodoc"] = true,
			["type"] = Check.valuetype.STRING,
			["description"] = "The airbase name",
		},
		["squadron"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.STRING,
			["description"] =
				"The squadron the slot is associated with",
		},
	})
end

--[[
-- Agent Facts:
-- cmdpending
-- scratchpad
-- loseticket
--
-- Agent Desc table:
-- groupId - pull from group data
-- airbase - figure out from group definition
-- squadron - set to false by default
--]]

function CheckPlayer:check(data)
	if data.objtype ~= dctenum.assetType.PLAYER then
		return true
	end

	return Check.check(self, data)
end

return CheckPlayer
