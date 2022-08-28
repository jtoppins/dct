--- SPDX-License-Identifier: LGPL-3.0

local aitasks = require("dct.ai.tasks")
local WS = require("dct.assets.worldstate")

local GroundIdle = require("libs.namedclass")("GroundIdle", WS.Action)
function GroundIdle:__init(agent)
	WS.Action.__init(self, agent, 1, {}, {
		WS.Property(WS.ID.IDLE, true),
	})
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
