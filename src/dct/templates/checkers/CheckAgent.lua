--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local Check   = require("dct.templates.checkers.Check")
local Agent   = require("dct.assets.Agent")

local notagent = {}

local CheckAgent = class("CheckAgent", Check)
function CheckAgent:__init()
	Check.__init(self, "Agent", {
		["sensors"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["sensors"],
			["description"] = [[
			]],
		},
		["actions"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["actions"],
			["description"] = [[
			]],
		},
		["goals"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["goals"],
			["description"] = [[
			]],
		},
	})
end

function CheckAgent:check(data)
	if notagent[data.objtype] then
		return true
	end

	return Check.check(self, data)
end

return CheckAgent
