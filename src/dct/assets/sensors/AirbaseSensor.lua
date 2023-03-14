-- SPDX-License-Identifier: LGPL-3.0

local class       = require("libs.namedclass")
local dctenum     = require("dct.enum")
local dctutils    = require("dct.libs.utils")
local vector      = require("dct.libs.vector")
local Timer       = require("dct.libs.Timer")
local DCTEvents   = require("dct.libs.DCTEvents")
local WS          = require("dct.assets.worldstate")
local aitasks     = require("dct.ai.tasks")
local UPDATE_TIME = 60
local NAVAID_REFRESH = 5

local function create_spot_fact(self, spot)
	local obj = {}
	obj.id   = spot.Term_Index
	obj.type = spot.Term_Type

	local node = WS.Facts.Node(obj, 1, WS.Facts.Node.nodeType.PARKING)
	node.position = WS.Attribute(vector.Vector3D(spot.vTerminalPos))
	self.agent:setFact("parking"..spot.Term_Index, node)
end

--- @classmod AirbaseSensor
-- Represents an Airbase. Airbases can be captured and have various
-- squadrons stationed at the airbase.
local AirbaseSensor = class("AirbaseSensor", WS.Sensor, DCTEvents)
function AirbaseSensor:__init(agent)
	WS.Sensor.__init(self, agent, 50)
	DCTEvents.__init(self)
	self.timer = Timer(UPDATE_TIME)
	self.navaid_counter = 0
	self.departure_cntr = 0

	local handlers = {}

	if AirbaseSensor.capturable[self.agent.type] == true then
		handlers[dctenum.event.DCT_EVENT_CAPTURED] =
			self.handleCapture
	end

	self:_overridehandlers(handlers)
	self.capturable = nil
	self.linkmap = nil
end

AirbaseSensor.capturable = {
	[dctenum.assetType.AIRBASE]  = true,
	[dctenum.assetType.FARP]     = true,
}

AirbaseSensor.linkmap = {
	[dctenum.assetType.AIRBASE] = "airdromeId",
	[dctenum.assetType.CV]      = "linkUnit",
	[dctenum.assetType.FARP]    = "helipadId",
}

function AirbaseSensor:activateNavaids(ab)
	if ab == nil or Object.getCategory(ab) ~= Object.Category.UNIT then
		return
	end

	local tasklist = {}
	local atc = self.agent:getDescKey("atc")
	local tacan = self.agent:getDescKey("tacan")
	local icls = self.agent:getDescKey("icls")

	if atc then
		table.insert(tasklist, aitasks.wraptask(
			aitasks.command.setFrequency(atc.frequency,
						     atc.modulation)))
	end

	if tacan then
		table.insert(tasklist, aitasks.wraptask(
			aitasks.command.createTACAN(ab,
						    tacan.callsign,
						    tacan.channel,
						    tacan.mode, nil,
						    false, true, false)))
	end

	if icls then
		table.insert(tasklist, aitasks.wraptask(
			aitasks.command.activateICLS(ab, icls)))
	end

	aitasks.execute(Unit.getController(ab), tasklist)
end

function AirbaseSensor:deactivateNavaids(ab)
	if ab == nil or Object.getCategory(ab) ~= Object.Category.UNIT then
		return
	end

	aitasks.execute(Unit.getController(ab), {
		aitasks.command.deactivateBeacon()
	})
end

function AirbaseSensor:refreshNavaids()
	local ab = Airbase.getByName(self.agent.name)

	if ab == nil or Object.getCategory(ab) ~= Object.Category.UNIT then
		return
	end

	self.navaid_counter = self.navaid_counter + 1
	if (self.navaid_counter % NAVAID_REFRESH) ~= 0 then
		return
	end

	self.navaid_counter = 0
	self:activateNavaids(ab)
end

--- An airbase is defined to be operational if its health state is
-- operational and it is spawned.
function AirbaseSensor:isOperational()
	local health = self.agent:WS():get(WS.ID.HEALTH).value
	local stance = self.agent:WS():get(WS.ID.STANCE).value

	return health == WS.Health.OPERATIONAL and
	       stance == WS.Stance.LAUNCHING and
	       self.agent:isSpawned()
end

function AirbaseSensor:setSilent(silent)
	local ab = Airbase.getByName(self.agent.name)

	if ab then
		ab:setRadioSilentMode(silent)

		if silent then
			self:deactivateNavaids(ab)
		else
			self:activateNavaids(ab)
		end
	end
end

function AirbaseSensor:notifyOperational()
	local operational = self:isOperational()

	self:setSilent(not operational)
	self.agent:notify(
		dctutils.buildevent.operational(self.agent, operational))
end

function AirbaseSensor:getRampSpots()
	local ab = Airbase.getByName(self.agent.name)

	if ab == nil or Object.getCategory(ab) ~= Object.Category.AIRDROME then
		return
	end

	-- set launching state for land airbases (airbase & farp) as they
	-- do not need to move to be ready for launching aircraft. The only
	-- way an airbase can be prevented from launching aircraft is if
	-- the runway is damaged.
	self.agent:WS():get(WS.ID.STANCE).value = WS.Stance.LAUNCHING

	local ramp_exclude = self.agent:getDescKey("ramp_exclude")
	local ground_spots = self.agent:getDescKey("ground_spots")

	for _, spot in ipairs(ab:getParking(true) or {}) do
		if ramp_exclude[spot.Term_Index] == nil then
			create_spot_fact(self, spot)
		end
	end

	for _, spot in pairs(ground_spots) do
		create_spot_fact(self, spot)
	end
end

function AirbaseSensor:setValues()
	local ab = Airbase.getByName(self.agent.name)
	local translation = vector.Vector3D(
		self.agent:getDescKey("departure_point"))
	local location = vector.Vector3D(self.agent:getDescKey("location"))

	self.agent:setDescKey("airdromeId", ab:getID())
	self.agent:setFact(WS.Facts.factKey.DEPARTURE,
			   location + translation)
end

function AirbaseSensor:setup()
	self:setSilent(true)
end

function AirbaseSensor:onHealthChange(--[[prev, current]])
	self:notifyOperational()
	self.agent:replan()
end

function AirbaseSensor:spawnPost()
	self.timer:reset()
	self.timer:start()

	self:setValues()
	self:getRampSpots()
	self:notifyOperational()
end

--- By definition a despawned airbase cannot have an operational tower
function AirbaseSensor:despawnPost()
	self.timer:stop()
	self:setSilent(true)
end

function AirbaseSensor:handleCapture(event)
	if event.target.name ~= self.agent.name then
		return
	end

	self.agent._logger:debug("captured - setting dead")
	self:setSilent(true)
	self.agent:setHealth(WS.Health.DEAD)
end

function AirbaseSensor:handleDeparture(event)
	if not self.isOperational() then
		return
	end

	local fact = WS.Facts.Event(event)
	self.departure_cntr = self.departure_cntr + 1
	self.agent:setFact("departure_"..tostring(self.departure_cntr), fact)
end

function AirbaseSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	if self.isOperational() then
		self:setValues()
		self:refreshNavaids()
	end

	self.timer:reset()
	self.timer:start()
	return false
end

return AirbaseSensor
