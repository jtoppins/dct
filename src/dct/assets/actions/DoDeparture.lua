-- SPDX-License-Identifier: LGPL-3.0

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Timer    = require("dct.libs.Timer")
local vector   = require("dct.libs.vector")
local WS       = require("dct.assets.worldstate")
local aitasks  = require("dct.ai.tasks")
local TIMEOUT  = 30

local function filter_departure_event(fact)
	return fact.type == WS.Facts.factType.EVENT and
	       fact.event.id == dctenum.event.DCT_EVENT_DEPARTURE
end

local function is_departure_event(_, fact)
	return filter_departure_event(fact)
end

--- @classmod DoDeparture
-- Setup a flight for departure from the airbase. We assume parking
-- is correctly setup. We just need to generate the departure flight plan
-- and spawn the flight.
local DoDeparture = require("libs.namedclass")("DoDeparture", WS.Action)
function DoDeparture:__init(agent, cost)
	WS.Action.__init(self, agent, cost or 10, {
		-- pre-conditions
		WS.Property(WS.ID.HEALTH, WS.Health.OPERATIONAL),
		WS.Property(WS.ID.STANCE, WS.Stance.LAUNCHING),
	}, {
		-- effects
		WS.Property(WS.ID.REACTEDTOEVENT,
			    dctenum.event.DCT_EVENT_DEPARTURE),
	}, 100)

	self.timer = Timer(TIMEOUT)
end

function DoDeparture:getFlight()
	local factkey
	local flight
	local ctime = dctutils.time()
	local min = ctime

	for key, fact in self.agent:iterateFacts(filter_departure_event) do
		local takeoff = fact.event.takeoff

		if takeoff <= ctime and takeoff <= min then
			min = takeoff
			factkey = key
			flight = fact.event.agent
		end
	end

	if factkey ~= nil then
		self.agent:setFact(factkey, nil)
	end

	return flight
end

function DoDeparture:enter()
	self.timer:reset(TIMEOUT)
	self.timer:start()

	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local flight = assetmgr:getAsset(self:getFlight())
	if flight == nil then
		self.timer:reset(5)
		self.timer:start()
		return
	end

	local dpoint = self.agent:getFact(WS.Facts.factKey.DEPARTURE)
	local wpt

	if dpoint == nil then
		local translation = vector.Vector3D(
			self.agent:getDescKey("departure_point"))
		local location = vector.Vector3D(
			self.agent:getDescKey("location"))
		dpoint = location + translation
	end

	wpt = aitasks.Waypoint(dpoint,
			       aitasks.Waypoint.wpType.TURNING_POINT,
			       aitasks.Waypoint.wpAction.TURNING_POINT,
			       flight:getDescKey("cruisespeed"))
	wpt:addTask(aitasks.task.orbit(AI.OrbitPattern.CIRCLE))

	for _, grp in pairs(flight.desc.tpldata) do
		if next(grp.data.units) ~= nil then
			table.insert(grp.data.route.points, wpt:raw())
		end
	end

	flight:spawn()
end

function DoDeparture:isComplete()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	if not self.agent:hasFact(is_departure_event) then
		self.agent:WS():get(WS.ID.REACTEDTOEVENT).value =
			dctenum.event.DCT_EVENT_DEPARTURE
	end

	return true
end

return DoDeparture
