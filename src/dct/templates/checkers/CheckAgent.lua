--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local utils   = require("libs.utils")
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

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

	local defaults = dct.settings.agents[data.objtype]

	for k, _ in pairs(self.options) do
		if next(data[k]) == nil then
			data[k] = utils.deepcopy(defaults[k])
		end
	end
	return true
end

return CheckAgent
