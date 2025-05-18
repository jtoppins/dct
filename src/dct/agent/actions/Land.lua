--- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local dctenum = require("dct.enum")
local vector = require("dct.libs.vector")
local WS = require("dct.agent.worldstate")
local InAir = require("dct.agent.actions.InAir")
local aienum  = require("dct.ai.enum")
local aitasks = require("dct.ai.tasks")

-- TODO: may need to implement a timeout and despawn the units
-- if the units don't land in a reasonable amount of time.
-- Also, need to consider airbase settings, needing not to land
-- to say the agent has recovered at the airbase.

local Land = class("Land", InAir)
function Land:__init(agent)
	InAir.__init(self, agent, 3, {
		-- preconditions
		-- TODO: might need to set ROE to something 'safe'
		-- WS.Property(WS.ID.ROE, AI.Option.Air.val.ROE.RETURN_FIRE),
	}, {
		-- effects
		WS.Property(WS.ID.INAIR, false),
	}, 100)

	self.patternalt = 458  -- 1500ft
	if agent.type == dctenum.assetType.HELO then
		self.patternalt = 152  -- 500ft
	end
end

function Land.isSuitable(agent)
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType

	return is_bit_set(assetType.AIR_UNIT, agent.type)
end

-- Adjust the in-range distance based on the "rule of three".
-- Adjusted the rule to accomidate a 6 deg slope which is
-- about 1.57NM per 1000 ft of altitude or in game units
-- 2.9Km per 304.8m
function Land:calcInRange()
	local alt = self.agent:getPoint().y - self.destination.position.y

	self.inrange_dist = ((alt / 305) * 2908) + 9300
end

function Land:setRoute()
	local pos2d = vector.Vector2D(self.agent:getPoint())
	local abpos2d = vector.Vector2D(self.destination.position)
	local unitvec = vector.unitvec(vector.Vector2D(pos2d - abpos2d))

	local wp1 = aitasks.Waypoint(self.destination.position +
			vector.Vector3D(9300 * unitvec, 100),
			aitasks.Waypoint.wpType.TURNING_POINT,
			aitasks.Waypoint.wpAction.TURNING_POINT,
			self.agent:getDescKey("cruisespeed"),
			"Terminal")
	wp1:setAlt(self.destination.position.y + self.patternalt,
		   AI.Task.AltitudeType.BARO)

	local wp2 = aitasks.Waypoint(self.destination.position,
			aitasks.Waypoint.wpType.LAND,
			aitasks.Waypoint.wpAction.LANDING,
			self.agent:getDescKey("cruisespeed"),
			"Land")
	if self.destination.abdata.unitid == nil then
		wp2.airdromeId = self.destination.abdata.abid
	else
		if self.agent.type == dctenum.assetType.HELO then
			wp2.helipadId = self.destination.abdata.unitid
		else
			wp2.linkUnit = self.destination.abdata.unitid
		end
	end

	local route = aitasks.Route(true, {wp1, wp2})
	self.agent:doTasksForeachGroup({
		-- set formation to something approperate for a congested
		-- airspace
		aitasks.wraptask(aitasks.option.createAirFormation(
			aienum.FORMATION.TYPE.ECHELON_RIGHT,
			aienum.FORMATION.DISTANCE.CLOSE)),
		-- TODO: set group to tower frequency
		-- aitasks.wraptask(
		--	aitasks.command.setFrequency(freq, modulation)),

		-- set the route we are going to take
		aitasks.wraptask(route:raw()),
	})
end

function Land:enter()
	InAir.enter(self)
	self.destination = self.agent:getDescKey("destination")
	self:calcInRange()
	self.inrange = false
	self.landcmd = false
end

--- Wait until all units of the group land.
function Land:isComplete()
	if self.inrange == false then
		local dist = vector.distance(self.destination.position,
					     self.agent:getPoint())
		self.inrange = (dist <= self.inrange_dist)
		return WS.Action.Result.CONTINUE
	end

	if self.landcmd == false then
		self:setRoute()
		self.landcmd = true
		return WS.Action.Result.CONTINUE
	end

	self:processChangeState()
	if self.agent:WS():get(WS.ID.INAIR).value == true then
		return WS.Action.Result.CONTINUE
	end

	self.destination = nil
	return WS.Action.Result.SUCCESS
end

return Land
