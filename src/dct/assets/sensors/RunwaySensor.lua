-- SPDX-License-Identifier: LGPL-3.0

local class      = require("libs.namedclass")
local dctenum    = require("dct.enum")
local vector     = require("dct.libs.vector")
local DCTEvents  = require("dct.libs.DCTEvents")
local WS         = require("dct.assets.worldstate")

--- @classmod RunwaySensor
-- Detects runway geometry associated with an airbase and determines if
-- a weapon impacted within the runway's boundary.

--- Represents a runway object and its state for an airbase.
--
-- @field name Name of the runway
-- @field center center of the runway
-- @field points points describing the four corners of the runway
-- @field AB 2D vector from point A to B
-- @field BC 2D vector from point B to C
-- @field dotAB vector dot product of AB * AB
-- @field dotBC vector dot product of BC * BC
local Runway = class("Runway")
function Runway:__init(rwy)
	local center = vector.Vector2D(rwy.position)
	local theta = rwy.course * -1
	local v1 = vector.Vector2D.create(math.cos(theta), math.sin(theta))
	local v2 = vector.Vector2D.create(-v1.y, v1.x)

	v1 = (rwy.length / 2) * v1
	v2 = (rwy.width / 2) * v2

	self.name   = rwy.name
	self.center = center
	self.points = {
		center + v1 + v2,
		center - v1 + v2,
		center - v1 - v2,
		center + v1 - v2,
	}
	self.AB    = self.points[1] - self.points[2]
	self.BC    = self.points[2] - self.points[3]
	self.dotAB = vector.dot(self.AB, self.AB)
	self.dotBC = vector.dot(self.BC, self.BC)
end

--- Check if runway was hit by a bomb that landed close by.
-- An impact point M is only inside runway area defined by points
-- A, B, & C if and only if (IFF);
--    0 <= dot(AB,AM) <= dot(AB,AB) && 0 <= dot(BC,BM) <= dot(BC,BC)
-- reference: https://stackoverflow.com/a/2763387
--
-- @param p point to test
-- @return bool true if point p is inside bounds of runway
function Runway:contains(p)
	local M = vector.Vector2D(p)
	local AM = self.points[1] - M
	local BM = self.points[2] - M
	local dotAM = vector.dot(self.AB, AM)
	local dotBM = vector.dot(self.BC, BM)

	if (0 <= dotAM <= self.dotAB) and
	   (0 <= dotBM <= self.dotBC) then
		return true
	end
	return false
end

function Runway:draw(id, coa, bordertype, bordercolor, fillcolor)
	trigger.action.removeMark(id)
	trigger.action.quadToAll(coa, id,
				 self.points[1]:raw(),
				 self.points[2]:raw(),
				 self.points[3]:raw(),
				 self.points[4]:raw(),
				 bordercolor, fillcolor, bordertype)
end

--- Detects runway geometry associated with an airbase and determines if
-- a weapon impacted within the runway's boundary.
local RunwaySensor = class("RunwaySensor", WS.Sensor, DCTEvents)
function RunwaySensor:__init(agent)
	WS.Sensor.__init(self, agent, 5)
	DCTEvents.__init(self)

	self._expmass  = 30
	self._runways  = {}

	self:_overridehandlers({
		[dctenum.event.DCT_EVENT_IMPACT] = self.handleImpact,
	})
end

function RunwaySensor:setAgentHealth(health)
	self.agent:setFact(WS.Facts.factKey.HEALTH,
		WS.Facts.Value(WS.Facts.factType.HEALTH, health, 1.0))
end

function RunwaySensor:marshal()
	self.agent.desc.runwayhealth =
		self.agent:getFact(WS.Facts.factKey.HEALTH).value.value
end

function RunwaySensor:setup()
	local ab = Airbase.getByName(self.agent.name)

	if ab == nil then
		self.agent._logger:info("Deleting Agent as underlying DCS"..
					"Airbase doesn't exist")
		self.agent:setDead(true)
		return
	end

	local rwys = ab:getRunways() or {}

	for _, rwy in pairs(rwys) do
		table.insert(self._runways, Runway(rwy))
	end

	local health = self.agent.desc.runwayhealth or 1

	self:setAgentHealth(health)
	if health < 1 then
		self.agent:WS():get(WS.ID.DAMAGED).value = true
	end
end

function RunwaySensor:handleImpact(event)
	if event.initiator.desc.warhead.explosiveMass < self._expmass then
		return
	end

	for _, rwy in ipairs(self._runways) do
		if rwy:contains(event.point) then
			self.agent:WS():get(WS.ID.DAMAGED).value = true
			self:setAgentHealth(0)
			self.agent:replan()
			break
		end
	end
end

return RunwaySensor
