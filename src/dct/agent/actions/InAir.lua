--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local DCTEvents = require("dct.libs.DCTEvents")
local WS = require("dct.agent.worldstate")

local InAir = class("InAir", WS.Action, DCTEvents)
function InAir:__init(agent, cost, precond, effects, order)
	WS.Action.__init(self, agent, cost, precond, effects, order)
	DCTEvents.__init(self)
	self._inair = {}
	self._inairdirty = false

	self:_overridehandlers({
		[world.event.S_EVENT_DEAD]    = self.handleDead,
		[world.event.S_EVENT_CRASH]   = self.handleDead,
		[world.event.S_EVENT_LAND]    = self.handleInAirChange,
		[world.event.S_EVENT_TAKEOFF] = self.handleInAirChange,
	})
end

function InAir:handleDead(event)
	local unit = event.initiator

	self._inair[unit:getName()] = nil
	self._inairdirty = true
end

function InAir:handleInAirChange(event)
	local unit = event.initiator
	local inair = true

	if event.id == world.event.S_EVENT_LAND then
		inair = false
	end

	self._inair[unit:getName()] = inair
	self._inairdirty = true
end

function InAir:processChangeState()
	if self._inairdirty == false then
		return
	end

	self._inairdirty = false
	local inair = true
	local onground = false

	for _, v in pairs(self._inair) do
		onground = onground or v
		inair = inair and v
	end

	if inair == true then
		self.agent:WS():get(WS.ID.INAIR).value = true
	elseif onground == false then
		self.agent:WS():get(WS.ID.INAIR).value = false
	end
end

function InAir:enter()
	self._inair = {}
	self._inairdirty = false

	for _, unit in self.agent:iterateUnits() do
		local U = Unit.getByName(unit.name)

		if U then
			self._inair[unit.name] = U:inAir()
		end
	end
end

return InAir
