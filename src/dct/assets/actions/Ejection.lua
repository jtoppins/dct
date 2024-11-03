-- SPDX-License-Identifier: LGPL-3.0

--- Ejection module
-- @module Ejection

require("libs")
local class = libs.classnamed
local WS = require("dct.assets.worldstate")

local function is_eject_event(_ --[[key]], fact)
	return fact.type == WS.Facts.factType.EVENT and
	       fact.event.id == world.event.S_EVENT_EJECTION
end

local function any_event(_ --[[key]], fact)
	return fact.type == WS.Facts.factType.EVENT
end

--- @classmod Ejection
--
local Ejection = class("Ejection", WS.Action)
function Ejection:__init(agent)
	WS.Action.__init(self, agent, 90, {
		-- pre-conditions
		-- none
	}, {
		-- effects
		WS.Property(WS.ID.REACTEDTOEVENT, true),
	})
	self.factkey = nil
end

function Ejection:checkProceduralPreconditions(--[[agent]])
	local rc, key = self.agent:hasFact(is_eject_event)

	if rc then
		self.factkey = key
	else
		self.factkey = nil
	end
	return rc
end

function Ejection:enter()
	--local fact = self.agent:getFact(self.factkey)

	-- delete the fact from the Agent
	self.agent:setFact(self.factkey, nil)
	self.factkey = nil

	-- TODO: create pilot agent
	trigger.action.outText("TODO: pilot agent created", 10, false)

	if not self.agent:hasFact(any_event) then
		self.agent:WS():get(WS.ID.REACTEDTOEVENT).value = true
	end
end

return Ejection
