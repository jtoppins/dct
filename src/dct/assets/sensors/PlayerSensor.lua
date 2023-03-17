-- SPDX-License-Identifier: LGPL-3.0

require("math")
local class     = require("libs.namedclass")
local utils     = require("libs.utils")
local dctenum   = require("dct.enum")
local dctutils  = require("dct.libs.utils")
local Timer     = require("dct.libs.Timer")
local DCTEvents = require("dct.libs.DCTEvents")
local loadout   = require("dct.ui.loadouts")
local WS        = require("dct.assets.worldstate")
local UPDATE_TIME = 30

local function playerIsDead()
	return false
end

--- @classmod PlayerSensor
-- Manages player slot related agent state.
--
-- @field timer how often this sensor updates
-- @field ejection tracks if an ejection event has already been registered
--        for this agent
-- @field _operstate tracks if the airbase/carrier this aircraft is tied to
--        is operational, thus should this player slot be enabled
-- @field _syncstate tracks if the agent needs to complete processing
--        remaining events before the slot should be enabled
-- @field _keyjoin
-- @field _keykick
-- @field _keyeject the key in Agent.memory the event fact should be stored
--
local PlayerSensor = class("PlayerSensor", WS.Sensor, DCTEvents)
function PlayerSensor:__init(agent)
	WS.Sensor.__init(self, agent, 5)
	DCTEvents.__init(self)
	self.timer      = Timer(UPDATE_TIME)
	self.ejection   = false
	self.birth      = false
	self._operstate = false
	self._syncstate = true
	self._keyjoin   = self.__clsname..".join"
	self._keykick   = self.__clsname..".kick"
	self._keyeject  = self.__clsname..".eject"

	trigger.action.setUserFlag(self.agent.name, false)
	trigger.action.setUserFlag(
		dctutils.build_kick_flagname(self.agent.name),
		dctenum.kickCode.NOKICK)

	self:_overridehandlers({
		[world.event.S_EVENT_BIRTH]    = self.handleBirth,
		[world.event.S_EVENT_TAKEOFF]  = self.handleTakeoff,
		[world.event.S_EVENT_EJECTION] = self.handleEjection,
		[world.event.S_EVENT_DEAD]     = self.handleLoseTicket,
		[world.event.S_EVENT_CRASH]    = self.handleLoseTicket,
		[world.event.S_EVENT_LAND]     = self.handleLand,
		[dctenum.event.DCT_EVENT_OPERATIONAL] = self.handleBaseState,
	})

        -- delete the agent's marshal/unmarshal functions as Player
        -- agents do not need to be serialized
        agent.marshal   = nil
        agent.unmarshal = nil

        -- Player agents cannot die, prevent them from ever being cleaned
        -- up by the AssetManager
        agent.isDead = playerIsDead
end

function PlayerSensor:setSync(val)
	self._syncstate = val
end

function PlayerSensor:isEnabled()
	return self.agent:isSpawned() and self._operstate and self._syncstate
end

function PlayerSensor:doEnable()
	local enabled = self:isEnabled()
	trigger.action.setUserFlag(self.agent.name, enabled)
	self.agent._logger:debug("setting enable flag: %s", tostring(enabled))
end

function PlayerSensor:postFact(key, fact)
	self.agent:setFact(key, fact)
	self.agent:WS():get(WS.ID.REACTEDTOEVENT).value = false
	self.agent:replan()
	if fact.event.id == dctenum.event.DCT_EVENT_PLAYER_KICK then
		self:setSync(false)
		self:doEnable()
	end
end

function PlayerSensor:handleBirth(event)
	if not self:isEnabled() then
		self.agent:setFact(WS.Facts.factKey.BLOCKSLOTMSG,
				   WS.Facts.PlayerMsg(
			"Warning: you have spawned in a disabled "..
			"slot, slot blocker potentially broken.", 20))
	end

	self.ejection = false
	self.birth = true
	self.agent:setFact(WS.Facts.factKey.LOSETICKET,
		WS.Facts.Value(WS.Facts.factType.LOSETICKET, false))
	self:postFact(self._keyjoin, WS.Facts.Event(
		dctutils.buildevent.playerJoin(event.initiator:getName())))
end

function PlayerSensor:handleTakeoff(--[[event]])
	local ok = loadout.check(self.agent)
	if not ok then
		self:postFact(self._keykick, WS.Facts.Event(
			dctutils.buildevent.playerKick(
				dctenum.kickCode.LOADOUT, self)))
		return
	end

	self.agent:setFact(WS.Facts.factKey.LOSETICKET,
		WS.Facts.Value(WS.Facts.factType.LOSETICKET, true))
	self.agent:WS():get(WS.ID.INAIR).value = true
end

-- If returned to an authorized airbase clear loseticket flag.
-- An authorized airbase is any base defined as an asset for
-- the same side.
function PlayerSensor:handleLand(event)
	if event.place == nil then
		return
	end

	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local airbase = assetmgr:getAsset(event.place:getName())

	self.agent:WS():get(WS.ID.INAIR).value = false
	if (airbase and airbase.owner == self.agent.owner) or
	   event.place:getName() == self.agent:getDescKey("basedat") then
		self.agent:setFact(WS.Facts.factKey.LOSETICKET,
			WS.Facts.Value(WS.Facts.factType.LOSETICKET, false))
		self.agent:setFact(WS.Facts.factKey.LANDSAFEMSG,
				   WS.Facts.PlayerMsg(
			"Welcome home. You are able to safely disconnect"..
			" without costing your side tickets.", 20))
	end
end

function PlayerSensor:handleEjection(event)
	if self.ejection or not self.agent:WS():get(WS.ID.INAIR).value then
		return
	end

	self.ejection = true
	self:postFact(self._keyeject, WS.Facts.Event(event))
end

function PlayerSensor:handleLoseTicket(--[[event]])
	self.agent:setFact(WS.Facts.factKey.LOSETICKET,
		WS.Facts.Value(WS.Facts.factType.LOSETICKET, true))
	self:postFact(self._keykick, WS.Facts.Event(
		dctutils.buildevent.playerKick(dctenum.kickCode.DEAD, self)))
end

function PlayerSensor:handleBaseState(event)
	if event.initiator.name ~= self.agent:getDescKey("basedat") then
		self.agent._logger:warn(
			"received unknown event %s(%d) from initiator(%s)",
			utils.getkey(dctenum.event, event.id),
			event.id, event.initiator.name)
		return
	end
	self._operstate = event.state
	self.agent._logger:debug("setting operstate: %s", tostring(event.state))
	self:doEnable()
end

function PlayerSensor:spawnPost()
	self.timer:reset()
	self.timer:start()
	self:doEnable()
end

function PlayerSensor:despawnPost()
	self.timer:stop()
	self:doEnable()
end

function PlayerSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	if self.birth and not dctutils.isalive(self.agent.name) then
		self.birth = false
		self:postFact(self._keykick, WS.Facts.Event(
			dctutils.buildevent.playerKick(dctenum.kickCode.EMPTY,
						       self)))
	end

	self.timer:reset()
	self.timer:start()
	return false
end

return PlayerSensor
