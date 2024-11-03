-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class   = libs.classnamed
local dctenum = require("dct.enum")
local Timer   = require("dct.libs.Timer")
local WS      = require("dct.assets.worldstate")
local UPDATE_TIME = 120

--- @classmod FuelSensor

--- finds the lowest fuel value for all units of the agent. An assumption
-- is made that all units are of the same type.
--
-- @param agent the Agent class reference we are concerned with
-- @return
--    first value is the lowest fuel state
--    second value is the aircraft type
local function find_lowest_fuel_forall_units(agent)
	local fuel = 100
	local actype = "invalid"

	for _, unit in agent:iterateUnits() do
		local U = Unit.getByName(unit.name)

		if U then
			fuel = math.min(fuel, U:getFuel())
			if actype == "invalid" then
				actype = U:getTypeName()
			end
		end
	end
	return fuel, actype
end

local function is_home_plate(_, fact)
	return fact.type == WS.Facts.factType.NODE and
	       fact.objtype.value == WS.Facts.Node.nodeType.HOMEBASE
end

--- Calculate the Bingo fuel mass for the Agent.
-- Calculating Bingo is usually done during mission planning and consists of
-- a mandatory reserve (we will use 2000lbs or 20mins whichever is greater)
-- plus the amount of fuel required to fly back to homeplate.
--
-- First obtain the mandatory fuel reserve, pre-calculated and stored in
--    the description table of the Agent.
-- Second determine if there is a pre-calculated path to homeplate if not
--    use a predefined amount of fuel remaining.
local function find_bingo(agent, acdesctbl)
	local reservemass = agent:getDescKey("reservefuel")
	local rtbspeed = agent:getDescKey("cruisespeed")
	local ok, homefact = agent:hasFact(is_home_plate)
	local bingomass = reservemass

	if ok then
		-- find the time it will take to get back to base
		bingomass = bingomass +
			(acdesctbl.Kmax *
			 (homefact.path.value.length / rtbspeed))
	else
		-- this branch should not be used often as the homeplate
		-- fact should be known
		bingomass = bingomass + (acdesctbl.fuelMassMax * 0.1)
	end

	return bingomass
end

--- Monitors how much fuel the aircraft group has remaining. Determins the
-- point when the aircraft fuel state is at a point that it no longer
-- has fuel (HASFUEL = false).
local FuelSensor = class("FuelSensor", WS.Sensor)
function FuelSensor:__init(agent)
	if dctenum.assetClass.AIRCRAFT[agent.type] == nil then
		return nil
	end

	WS.Sensor.__init(self, agent, 40)
	self.timer = Timer(UPDATE_TIME)
end

function FuelSensor:spawnPost()
	self.timer:reset()
	self.timer:start()
end

function FuelSensor:despawnPost()
	self.timer:stop()
end

function FuelSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	local hasfuel = self.agent:WS():get(WS.ID.HASFUEL).value
	local fuel, actype = find_lowest_fuel_forall_units(self.agent)

	-- We can determine Bingo by getting a little bit of information
	-- about the aircraft type.
	local acdesc = Unit.getDescByName(actype)
	local curFuelMass = fuel * acdesc.fuelMassMax
	local bingoMass = find_bingo(self.agent, acdesc)

	self.agent:setFact(WS.Facts.factKey.FUEL, WS.Facts.Value(
		WS.Facts.factType.FUEL, fuel))

	-- TODO: This may not completely work for targets beyond the range of
	-- the airframe and refueling is required. Currently do not worry
	-- about this.
	if bingoMass >= curFuelMass and hasfuel then
		self.agent:WS():get(WS.ID.HASFUEL).value = false
	elseif not hasfuel and fuel > self.agent:getDescKey("refuelpct") then
		self.agent:WS():get(WS.ID.HASFUEL).value = true
	end

	self.timer:reset()
	self.timer:start()
	return true
end

return FuelSensor
