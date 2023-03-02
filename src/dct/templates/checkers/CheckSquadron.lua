--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")

local issquadron = {
	[dctenum.assetType.SQUADRON] = true,
}

local function check_ato(data)
	local msnlist = {}

	for _, msntype in pairs(data.ato) do
		local msnstr = string.upper(msntype)
		if type(msntype) ~= "string" or
		   dctenum.missionType[msnstr] == nil then
			return false, "ato",
				"invalid mission type: "..tostring(msnstr)
		end
		msnlist[msnstr] = dctenum.missionType[msnstr]
	end
	data.ato = msnlist
	return true
end

--- @class CheckSquadron
local CheckSquadron = class("CheckSquadron", Check)
function CheckSquadron:__init()
	Check.__init(self, "Squadron", {
		["ato"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] =
			"",
		},
		["range"] = {
			["default"] = 555600, -- 300 NM
			["type"] = Check.valuetype.INT,
			["description"] = [[
Defines the maximum path distance a squadron will accept from their home base
to the target area. The value is in meters.]],
		},
		["airframe"] = {
			["default"] = "",
			["type"] = Check.valuetype.STRING,
			["description"] = [[
Defines the aircraft template to use with the squadron. A squadron may have
combined AI and players in one squadron. Player aircraft are not required to
be of the same airframe type. However, it is recommended you set `max_range`
or the squadron and thus players under the squadron may get assigned missions
they cannot complete. The template is referenced by name in the form:
`[<region>].<name>`, where `region` is optional. Example:
`foobar.myfancy_F15C`]],
		},
		["airbase"] = {
			["type"] = Check.valuetype.STRING,
			["description"] = [[
Name of the airbase this squadron is based at.
			]],
		},
		["limit"] = {
			["default"] = -1,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Maximum number of aircraft the squadron can have, -1 unlimited.
			]],
		},
		["size"] = {
			["default"] = -1,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Starting number of aircraft the squadron has, -1 unlimited.
			]],
		},
		["all_players"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
If true auto associate all player slots at the airbase with the squadron.
			]],
		},
	})
end

function CheckSquadron:check(data)
	if issquadron[data.objtype] == nil then
		return true
	end

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

	return check_ato(data)
end

return CheckSquadron
