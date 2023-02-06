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
			["agent"] = true,
			["type"] = Check.valuetype.INT,
			["description"] = "group ID of the player group",
		},
		["parking"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.INT,
			["description"] = "The parking id",
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

function CheckPlayer:check(data)
	if data.objtype ~= dctenum.assetType.PLAYER then
		return true
	end

	data.overwrite = false
	data.rename = false

	return Check.check(self, data)
end

return CheckPlayer
