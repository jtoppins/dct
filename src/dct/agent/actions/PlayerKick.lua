-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class    = libs.classnamed
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local WS       = require("dct.agent.worldstate")

local reasons = {
	[dctenum.kickCode.LOADOUT] =
		"You have been removed to spectator for flying "..
		"with an invalid loadout. "..dctutils.notifymsg,
	[dctenum.kickCode.DEAD] =
		"You have been kicked from the slot because the game"..
		" thinks you are dead.",
	[dctenum.kickCode.EMPTY] =
		"You have been kicked from the slot because the game"..
		" thought the slot was empty and slot management was"..
		" resetting the slot state.",
}

local function is_kick_event(_ --[[key]], fact)
	return fact.type == WS.Facts.factType.EVENT and
	       fact.event.id == dctenum.event.DCT_EVENT_PLAYER_KICK
end

--- @classmod PlayerKick
-- Request player to be kicked from slot.
--
-- Posts a request for the player to be kicked from the slot.
-- This depends on an outside DCS hooks script to be running
-- which will kick the player from the slot and reset the
-- kick flag.
-- This will then allow the player state the be reset allowing
-- another player to join the slot.
--
-- Assign static action cost values so the order of execution of actions
-- is preserved.
-- PlayerJoin - least expensive
-- Eject      - in the middle
-- PlayerKick - most expensive
local PlayerKick = class("PlayerKick", WS.Action)
function PlayerKick:__init(agent)
	WS.Action.__init(self, agent, 100, {
		-- pre-conditions
		-- none
	}, {
		-- effects
		WS.Property(WS.ID.REACTEDTOEVENT, true),
	})
	self.factkey = nil
end

function PlayerKick:checkProceduralPreconditions()
	local rc, key = self.agent:hasFact(is_kick_event)

	if rc then
		self.factkey = key
	else
		self.factkey = nil
	end
	return rc
end

function PlayerKick:enter()
	local flagname = dctutils.build_kick_flagname(self.agent.name)
	local kickfact = self.agent:getFact(self.factkey)
	local losefact = self.agent:getFact(WS.Facts.factKey.LOSETICKET)
	local msg = reasons[kickfact.event.code] or
		"You have been kicked from the slot for an unknown reason."

	self.agent:setFact(WS.Facts.factKey.KICKMSG,
			   WS.Facts.PlayerMsg(msg, 20))
	trigger.action.setUserFlag(flagname, kickfact.event.code or
		dctenum.kickCode.UNKNOWN)
	self.agent._logger:debug("requesting kick: %s; reason: %d",
		flagname, kickfact.event.code)

	if losefact and losefact.value.value then
		self.agent:setHealth(WS.Health.DEAD)
	end

	-- clear all facts from agent
	self.factkey = nil
	self.agent:deleteAllFacts()
	self.agent:WS():get(WS.ID.REACTEDTOEVENT).value = true

	-- tell the player sensor the agent has sync'ed its state
	kickfact.event.psensor:setSync(true)
	kickfact.event.psensor:doEnable()
end

return PlayerKick
