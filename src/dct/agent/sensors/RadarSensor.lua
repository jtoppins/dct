-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local dctenum = require("dct.enum")
local Timer   = require("dct.libs.Timer")
local vector  = require("dct.libs.vector")
local WS      = require("dct.agent.worldstate")

--- Determines if a unit has a radar sensor.
-- @return true if the unit has a radar
local function unit_has_radar(unit)
	local U = Unit.getByName(unit.name)

	if U == nil then
		return false
	end

	return U:hasSensors(Unit.SensorType.RADAR)
end

--- Checks if the fact is of type CHARACTER and if the fact
-- was added by the RadarSensor.
-- @return bool
local function radar_character(key, fact)
	return fact.type == WS.Facts.factType.CHARACTER and
	       string.match(key, "^radar_.*") ~= nil
end

local function normalized_distance(agentloc, objectloc, range)
	local dist = vector.distance(agentloc, objectloc)
	local ndist = 0

	if dist < range then
		ndist = 1 - (dist / range)
	end
	return ndist
end

--- Updates Character fact with new contact information
local function update_fact(agent, key, fact, contact)
	fact.updatetime = contact.lastTime

	-- if the contact type is known we can determine if it is a threat
	-- to us or not. If it is not a threat to us do not add the contact.
	if contact.type then
		fact.owner = WS.Attribute(contact.object:getCoalition())

		--[[
		local val = agent:isThreatOrTarget(contact.object)

		if val == TARGET then
			fact.object.confidence = 0.5
		elseif val == 0 then
			-- drop contact it is not a threat or possible target
			agent:setFact(key, nil)
			return
		end
		--]]

		-- TODO: the issue trying to be solved is how to filter
		-- contacts that get added to an agent's fact list based on
		-- if the contact can threaten the agent or the agent could
		-- possibly damage the contact. If neither are the case
		-- (example: an F-18 configured for A2A detects a silkworm
		-- missile TEL) there is no point in tracking the silkworm
		-- because the silkworm cannot damage the F-18 and the F-18
		-- cannot really damage the silkworm (assume no use of gun).
		--
		-- We should be able to tell this at the agent level by
		-- scoring the object's weapons or setting up a static table
		-- keyed on object type.
		--
		-- This is probably best left up to the campaign designer
		-- when defining their tactical template, requiring them to
		-- define a threat table.
		--
		-- I am kinda lost as to why I need this for an EWR/SAM
		-- site. The EWR just needs to share its contacts with other
		-- mission participants. All enemy "battleplanes" are
		-- possible targets. Anti-radiation missiles detected need
		-- to generate launch disturbances so the agent can possibly
		-- react to these. All other contacts need to be dropped.
	end

	if contact.distance then
		fact.position = WS.Attribute(vector.Vector3D(contact.lastPos),
			normalized_distance(agent:getDesc("location"),
				vector.Vector3D(contact.object:getPoint()),
				agent:getDesc("attackrange")))
		fact.velocity = WS.Attribute(vector.Vector3D(contact.lastVel))
	end

	agent:setFact(key, fact)
end

--- Applies character facts to the agent for a given Unit object using
-- the sensor types in detection. If the fact exists in agent only overwrite
-- the current fact if the contact data is newer.
--
-- @param agent Agent object to apply CharacterFact facts to
-- @param unit DCS Unit object to query for contacts
-- @param detection list of sensor types to use when getting the contact
--        list from unit
local function process_contacts(agent, unit, detection)
	if unit == nil then
		return nil
	end

	local ai = unit:getController()

	if ai == nil then
		return nil
	end

	for _, tgt in ipairs(ai:getDetectedTargets(unpack(detection))) do
		local name = tgt.object:getName()
		local key = "radar_"..name
		local fact = agent:getFact(key)
		local detected, _, lastTime, _, _, pos, vel =
			ai:isTargetDetected(tgt.object)

		tgt.detected = detected
		tgt.lastTime = lastTime
		tgt.lastPos  = pos
		tgt.lastVel  = vel

		if fact ~= nil and fact.updatetime < lastTime then
			update_fact(agent, key, fact, tgt)
		elseif fact == nil then
			fact = WS.Facts.Character(name, 0,
						  dctenum.objtype.UNIT)
			update_fact(agent, key, fact, tgt)
		end
	end

end

--- Use the underlying DCS model to detect contacts via radar.
-- Detects which units of the agent have matching attributes and
-- caches this information on spawn. The sensor will periodically
-- query these units for contacts which are added to the agent's
-- memory so that other systems can make decisions. The sensor will
-- remove all contacts and update the entries based on the underlying
-- detection model of the unit. The update rate of the sensor is
-- determined by the description key `radarupdate`.
-- This sensor will be disabled when the agent's sensor state is
-- off.
-- @type RadarSensor
local RadarSensor = class("RadarSensor", WS.Sensor)
function RadarSensor:__init(agent)
	WS.Sensor.__init(self, agent, 10)

	self.radarunits = {}
	self.timer = Timer(agent:getDescKey("radarupdate"))
	self.detection = agent:getDescKey("radardetection")
	self.ageout = agent:getDescKey("radarageout")
end

function RadarSensor:spawnPost()
	self.radarunits = {}
	for _, unit in self.agent:iterateUnits(unit_has_radar) do
		local desc = Unit.getDescByName(unit.type)
		local attrs = self.agent:getDescKey("radarattrs")


		for attr, _ in pairs(attrs) do
			if desc.attributes[attr] ~= nil then
				self.radarunits[unit.name] = true
				break
			end
		end
	end

	self.timer:reset()
	self.timer:start()
end

function RadarSensor:despawnPost()
	self.timer:stop()
end

function RadarSensor:update()
	self.timer:update()

	if self.agent:WS():get(WS.ID.SENSORSON).value == false or
	   next(self.radarunits) == nil or not self.timer:expired() then
		return false
	end

	-- add contacts
	for unitname, _ in pairs(self.radarunits) do
		process_contacts(self.agent,
				 Unit.getByName(unitname),
				 self.detection)
	end

	-- age out contacts
	local modeltime = timer.getTime()
	for key, fact in self.agent:iterateFacts(radar_character) do
		local t = modeltime - fact.updatetime

		if t > self.ageout then
			self.agent:setFact(key, nil)
		end
	end

	self.timer:reset()
	self.timer:start()
	return true
end

return RadarSensor
