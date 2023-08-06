-- SPDX-License-Identifier: LGPL-3.0

require("math")
local class     = require("libs.namedclass")
local pqueue    = require("libs.containers.pqueue")
local Timer     = require("dct.libs.Timer")
local DCTEvents = require("dct.libs.DCTEvents")
local uimenu    = require("dct.ui.groupmenu")
local WS        = require("dct.assets.worldstate")
local UPDATE_TIME = 5


local function is_player_msg(fact)
	return fact.type == WS.Facts.factType.PLAYERMSG
end

local function display_messages(agent, ctime, maxmsgs)
	local gid = agent:getDescKey("groupId")
	local pq = pqueue()
	local maxdelay = 0

	for key, fact in agent:iterateFacts(is_player_msg) do
		if fact.updatetime < ctime then
			pq:push(fact.value.confidence, key)
		end
	end

	while not pq:empty() and maxmsgs > 0 do
		local key = pq:pop()
		local fact = agent:getFact(key)

		trigger.action.outTextForGroup(gid, fact.value.value,
					       fact.delay, false)
		maxdelay = math.max(maxdelay, fact.delay)
		maxmsgs = maxmsgs - 1
		agent:setFact(key, nil)
	end
	return maxdelay
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
	self.timer:start()

	local ctime = timer.getTime()
	if ctime > self.lastsent then
		self.lastsent = ctime + display_messages(self.agent, ctime, 4)
	end

	-- TODO: draw any F10 elements the player has requested and are
	--       pending in memory

	return false
end

return PlayerUISensor
