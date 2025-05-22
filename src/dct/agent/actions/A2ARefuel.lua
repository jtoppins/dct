--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.agent.worldstate")

local A2ARefuel = class("A2ARefuel", WS.Action)
function A2ARefuel:__init(agent)
	WS.Action.__init(self, agent, 3, {
		-- preconditions
	}, {
		-- effects
		WS.Property(WS.ID.STANCE, WS.Stance.REFUELING),
	} --[[, order ]])

	self.complete = false
	self.tgtFuelState = .85
	self.tgtTankerName = nil
end

function A2ARefuel.isSuitable(agent)
	return agent:hasAttribute("Refuelable")
end

function A2ARefuel:checkProceduralPreconditions()
	-- TODO: check that a tanker is available from our memory,
	--   verify it has enough fuel for the group
	-- if no tanker available return false
	return false
end

function A2ARefuel:enter()
	self.complete = WS.Action.Result.CONTINUE

	-- TODO:
	-- set radio to tanker freq
	-- register group with tanker
	-- set tasking to refuel
end

--- Tracks when the action is complete.
function A2ARefuel:isComplete()
	if self.agent:getFact(WS.Facts.factKey.FUEL) >= self.tgtFuelState then
		self.complete = WS.Action.Result.SUCCESS
	end

	if self.complete == WS.Action.Result.SUCCESS then
		-- TODO: set group to fly formation on tanker while it is
		-- replanning
	end

	return self.complete
end

return A2ARefuel
