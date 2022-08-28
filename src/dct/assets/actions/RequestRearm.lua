--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local WS = require("dct.assets.worldstate")

local RequestRearm = require("libs.namedclass")("RequestRearm", WS.Action)
function RequestRearm:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {
		WS.Property(WS.ID.HASAMMO, false),
	}, {
		WS.Property(WS.ID.HASAMMO, true),
	})
end

function RequestRearm:enter()
	-- TODO: should this action have a timeout?
	local cmdr = dct.Theater.singleton():getCommander(self.agent.owner)
	local rqst = dctutils.buildrequest(dctenum.uiRequestType.REQUESTREARM,
					   self.agent)
	cmdr:postRequest(rqst)
end

function RequestRearm:isComplete()
	if self.agent:WS():get(WS.ID.HASAMMO).value == true then
		return true
	end
	return false
end

return RequestRearm
