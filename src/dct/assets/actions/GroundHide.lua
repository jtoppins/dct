--- SPDX-License-Identifier: LGPL-3.0

local utils   = require("libs.utils")
local Timer   = require("dct.libs.Timer")
local aitasks = require("dct.ai.tasks")
local WS      = require("dct.assets.worldstate")
local TIMEOUT = 60

local GroundHide = require("libs.namedclass")("GroundHide", WS.Action)
function GroundHide:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {
		-- pre-conditions
		WS.Property(WS.ID.SENSORSON, false),
		WS.Property(WS.ID.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD),
	}, {
		-- effects
		WS.Property(WS.ID.STANCE, WS.Stance.FLEEING),
	}, 100)
	self.timer = Timer(TIMEOUT, timer.getAbsTime)
end

function GroundHide:enter()
	local tasktbl = {
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.RED)),
	}

	self.timer:reset(utils.addstddev(TIMEOUT, 20))
	self.timer:start()
	self.agent:doTasksForeachGroup(tasktbl)
	self.agent:WS():get(WS.ID.STANCE).value = WS.Stance.FLEEING
end

function GroundHide:isComplete()
	self.timer:update()
	if self.timer:expired() then
		return true
	end
	return false
end

return GroundHide
