--- SPDX-License-Identifier: LGPL-3.0

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local WS       = require("dct.assets.worldstate")

local function is_join_event(_ --[[key]], fact)
	return fact.type == WS.Facts.factType.EVENT and
	       fact.event.id == dctenum.event.DCT_EVENT_PLAYER_JOIN
end

local function any_event(_ --[[key]], fact)
	return fact.type == WS.Facts.factType.EVENT
end

local PlayerJoin = require("libs.namedclass")("PlayerJoin", WS.Action)
function PlayerJoin:__init(agent)
	WS.Action.__init(self, agent, 1, {
		-- pre-conditions
		-- none
	}, {
		-- effects
		WS.Property(WS.ID.REACTEDTOEVENT, true),
	})
	self.factkey = nil
end

function PlayerJoin:checkProceduralPreconditions()
	local rc, key = self.agent:hasFact(is_join_event)

	if rc then
		self.factkey = key
	else
		self.factkey = nil
	end
	return rc
end

function PlayerJoin:enter()
	local fact = self.agent:getFact(self.factkey)
	local grp = Group.getByName(self.agent.name)
	local unit = Unit.getByName(fact.event.unit)
	local msn = self.agent:getMission()

	self.factkey = nil
	self.agent:deleteFacts(is_join_event)

	if not grp or not unit then
		self.agent:replan()
		return
	end

	self.agent:setDead(false)
	self.agent:setDescKey("groupId", grp:getID())
	self.agent:WS():get(WS.ID.INAIR).value = unit:inAir()
	if not self.agent:hasFact(any_event) then
		self.agent:WS():get(WS.ID.REACTEDTOEVENT).value = true
	end

	if msn then
		self.agent:setFact(WS.Facts.factKey.WELCOMMISSION,
			WS.Facts.PlayerMsg(string.format(
			"Welcome. Mission %d is already assigned to this "..
			"slot, use the F10 menu to get the briefing or "..
			"find another.", msn:getID()), 20))
		-- TODO: pull all mission facts and add them to the agent
	end

	self.agent:setFact(WS.Facts.factKey.WELCOMMISSION,
			   WS.Facts.PlayerMsg(dctutils.notifymsg, 20))
end

return PlayerJoin
