--- SPDX-License-Identifier: LGPL-3.0

local aitasks = require("dct.ai.tasks")
local WS = require("dct.assets.worldstate")

local SAMAttack = require("libs.namedclass")("SAMAttack", WS.Action)
function SAMAttack:__init(agent, cost)
	WS.Action.__init(self, agent, cost or 5, {
		-- pre-conditions
		WS.Property(WS.ID.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE),
		WS.Property(WS.ID.ATTARGETPOS, true),
	}, {
		-- effects
		WS.Property(WS.ID.TARGETDEAD, true),
		WS.Property(WS.ID.STANCE, WS.Stance.ATTACKING),
	},
	100)
end

local function has_targets(--[[key, fact]])
	-- TODO: write this, targets are any enemy character fact in-range
	-- character fact's position attribute confidence value is
	--return fact.type == WS.Facts.factType.CHARACTER and
end

--- This action is not valid if there are no targets or the agent
-- has no ammo.
function SAMAttack:checkProceduralPreconditions()
	if self.agent:WS():get(WS.ID.HASAMMO).value == false then
		return false
	end
	return self.agent:hasFact(has_targets)
end

function SAMAttack:enter()
	local tasktbl = {
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.RED)),
		aitasks.wraptask(aitasks.option.create(
			AI.Option.Ground.id.ENGAGE_AIR_WEAPONS,
			true)),
	}

	self.agent:doTasksForeachGroup(tasktbl)
end

function SAMAttack:isComplete()
	local rc = 0

	if self.agent:hasTargets() then
		rc = 10
	else
		self.agent:WS():get(WS.ID.TARGETDEAD).value = true
	end
	return rc
end

return SAMAttack
