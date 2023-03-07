--- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local utils   = require("libs.utils")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")
local Agent   = require("dct.assets.Agent")

local notagent = {
	[dctenum.assetType.INVALID] = true,
	[dctenum.assetType.SCRIPT]  = true,
	[dctenum.assetType.NODE]    = true,
}

local CheckAgent = class("CheckAgent", Check)
function CheckAgent:__init()
	Check.__init(self, "Agent", {
		["sensors"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["sensors"],
			["description"] = [[
Sensors monitor the agent's state. The available sensors are:]],
		},
		["actions"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["actions"],
			["description"] = [[
Actions are the set of action object the agent has available to it to
manipulate its state to a desired goal state. The follow list of actions
are:]],
		},
		["goals"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = Agent.objectType["goals"],
			["description"] = [[
Goals represent desired world states that an Agent attempts to achieve. The
following goals are available:]],
		},
	}, [[Agents are DCT assets that can think and will react to various
stimuli that occur in the theater.]])
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

	if data.debug > 0 then
		data.sensors["DebugSensor"] = 0
	else
		data.sensors["DebugSensor"] = nil
	end

	return true
end

return CheckAgent
