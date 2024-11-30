--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local aitasks = require("dct.ai.tasks")
local WS = require("dct.agent.worldstate")

local GroundIdle = class("GroundIdle", WS.Action)
function GroundIdle:__init(agent)
	WS.Action.__init(self, agent, 1, {}, {
		WS.Property(WS.ID.IDLE, true),
	}, 100)
end

function GroundIdle:enter()
	local tasktbl = {
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.AUTO)),
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ROE,
			AI.Option.Ground.val.ROE.RETURN_FIRE)),
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ENGAGE_AIR_WEAPONS,
			true)),
		aitasks.wraptask(aitasks.command.stopRoute(true)),
	}

	self.agent:doTasksForeachGroup(tasktbl)
	self.agent:WS():get(WS.ID.IDLE).value = true
end

--- never complete, we should only ever be executing this
-- action because there is nothing else to do. Force a higher
-- priority goal to be selected and force replanning
function GroundIdle:isComplete()
	return false
end

return GroundIdle
