-- SPDX-License-Identifier: LGPL-3.0

require("math")
local class     = require("libs.namedclass")
local Timer     = require("dct.libs.Timer")
local DCTEvents = require("dct.libs.DCTEvents")
local uimenu    = require("dct.ui.groupmenu")
local WS        = require("dct.assets.worldstate")
local UPDATE_TIME = 5


local function is_player_msg(fact)
	return fact.type == WS.Facts.factType.PLAYERMSG
end

local function find_next_msg(agent)
	local msg, key

	for k, fact in agent:iterateFacts(is_player_msg) do
		if msg == nil then
			msg = fact
			key = k
		elseif msg.updatetime > fact.updatetime then
			msg = fact
			key = k
		end
	end
	return key, msg
end

--- @classmod PlayerUISensor
-- Manages drawing UI elements to the player. Be that text messages, F10 map
-- elements, or F10 menu updates. This sensor handles these issues.
--
-- @field timer how often this sensor updates
--
local PlayerUISensor = class("PlayerUISensor", WS.Sensor, DCTEvents)
function PlayerUISensor:__init(agent)
	WS.Sensor.__init(self, agent, 10)
	DCTEvents.__init(self)
	self.timer = Timer(UPDATE_TIME)
	self.lastsent = 0

	self:_overridehandlers({
		[world.event.S_EVENT_BIRTH] = self.handleBirth,
	})
end

function PlayerUISensor:handleBirth(event)
	local grp = event.initiator:getGroup()
	uimenu.createMenu(grp)
end

function PlayerUISensor:spawnPost()
	self.timer:reset()
	self.timer:start()
end

function PlayerUISensor:despawnPost()
	self.timer:stop()
end

function PlayerUISensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end
	self.timer:reset()

	local modeltime = timer.getTime()
	if modeltime > self.lastsent then
		local key, msg = find_next_msg(self.agent)

		if msg ~= nil then
			self.agent:setFact(self, key, nil)
			self.lastsent = modeltime + msg.time.value
			trigger.action.outTextForGroup(
				self.agent:getDescKey("groupId"),
				msg.value.value,
				msg.delay,
				true)
		end
	end

	-- TODO: draw any F10 elements the player has requested and are
	--       pending in memory

	return false
end

return PlayerUISensor
