-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class        = libs.classnamed
local Timer        = require("dct.libs.Timer")
local vector       = require("dct.libs.vector")
local WS           = require("dct.agent.worldstate")
local agentutils   = require("dct.agent.utils")
local aitasks      = require("dct.ai.tasks")
local UPDATE_TIME  = 600

--- @classmod AircraftSensor
-- Sets defaults for aircraft groups and monitors which airbases
-- the group will use to recover to.
local AircraftSensor = class("AircraftSensor", WS.Sensor)
function AircraftSensor:__init(agent)
	WS.Sensor.__init(self, agent, 20)
	self.timer = Timer(UPDATE_TIME)
end

function AircraftSensor.isSuitable(agent)
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType

	return is_bit_set(assetType.AIR_UNIT, agent.type)
end

--- Cache some data stored in the template for the aircraft.
function AircraftSensor:setup()
	self.assetmgr = dct.Theater.singleton():getSystem(
				dct.libs.System.SYSTEMALIAS.ASSETMGR)
end

local function sortairbases(a, b)
	return a.dist < b.dist
end

-- Sets a last resort set of airbases based on a search of the agent
-- coalition's available bases and their distance to the agent where it
-- spawned. These bases are only set if the agent has no homebase nodes
-- set. No consideration is made if the airbase can support the aircraft.
function AircraftSensor:setHomebaseFact()
	if self.agent:hasFact(dct.agent.utils.is_homebase_fact) then
		return
	end

	local agentpos = self.agent:getPoint()
	local airbases = {}
	for _, base in ipairs(coalition.getAirbases(self.agent.owner)) do
		local info = {}
		info.name = base:getName()
		info.point = vector.Vector3D(base:getPoint())
		info.dist = vector.distance(agentpos, info.point)
		table.insert(airbases, info)
	end
	table.sort(airbases, sortairbases)

	local i = 1
	while i <= #airbases and i <= 2 do
		local node = agentutils.build_homebase_fact(airbases[i].name,
							    2 - i)
		self.agent:setFact(nil, node)
		i = i + 1
	end
end

function AircraftSensor:setBingoFact()
	local bingo = agentutils.fuel_bingo(self.agent, self.agent:getPoint())
	self.agent:setFact(WS.Facts.factKey.BINGO,
			   WS.Facts.Value(bingo, 1))
end

function AircraftSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	self:setBingoFact()
	self.timer:reset()
	self.timer:start()
	return true
end

function AircraftSensor:spawn()
	self.timer:reset()
	self.timer:start()
end

function AircraftSensor:spawnPost()
	local wraptask = aitasks.wraptask
	local roe = AI.Option.Air.val.ROE.RETURN_FIRE
	local defoptions = {
		wraptask(aitasks.option.create(
			AI.Option.Air.id.FLARE_USING,
			AI.Option.Air.val.FLARE_USING.AGAINST_FIRED_MISSILE)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.ECM_USING,
			AI.Option.Air.val.ECM_USING.USE_IF_ONLY_LOCK_BY_RADAR)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.REACTION_ON_THREAT,
			AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.ROE, roe)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.RTB_ON_BINGO, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, 0)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.PROHIBIT_AA, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.PROHIBIT_AG, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.PROHIBIT_JETT, true)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.JETT_TANKS_IF_EMPTY, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.PROHIBIT_AB, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.MISSILE_ATTACK,
			AI.Option.Air.val.MISSILE_ATTACK.TARGET_THREAT_EST)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.SILENCE, false)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.PROHIBIT_WP_PASS_REPORT, true)),
		wraptask(aitasks.option.create(
			AI.Option.Air.id.ALLOW_FORMATION_SIDE_SWAP, true)),
	}

	self.agent:doTasksForeachGroup(defoptions)
	self.agent:WS():get(WS.ID.ROE).value = roe
	self:setHomebaseFact()
	self:setBingoFact()
end

return AircraftSensor
