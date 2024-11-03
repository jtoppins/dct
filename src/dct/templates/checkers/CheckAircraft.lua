-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class   = libs.classnamed
local utils   = libs.utils
local dctenum = require("dct.enum")
local Check   = require("dct.libs.Check")

local RESERVETIME = 20 * 60 -- 20 minutes
local adtypes = {
	[dctenum.assetType.AIRPLANE] = true,
	[dctenum.assetType.HELO]     = true,
}

local dct_attrs = {
	["DCT_CAS"] = "DCT CAS",
	["DCT_LL"] = "DCT Low Level Attack",
}

local a10 = {
	[dct_attrs.DCT_CAS] = true,
	[dct_attrs.DCT_LL] = true,
}

local airframe_attr_fixups = {
	["F-15E"] = {
		["Multirole fighters"] = true,
		[dct_attrs.DCT_CAS] = true,
		[dct_attrs.DCT_LL] = true,
	},
	["A-10A"] = a10,
	["A-10C"] = a10,
	["A-10C_2"] = a10,
}

local CheckAircraft = class("CheckAircraft", Check)
function CheckAircraft:__init()
	Check.__init(self, "Aircraft", {
		["reservefuel"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
The amount of reserve fuel (in Kg) the aircraft must return to base with.
If not provided the value will be auto calculated from game data.]],
		},
		["cruisespeed"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
The speed (in m/s indicated) at which the aircraft is expected to fly at as
it is returning home. If not provided it will be auto calculated from game
data.]],
		},
		["refuelpct"] = {
			["agent"] = true,
			["default"] = 0.45,
			["type"] = Check.valuetype.RANGE,
			["values"] = {0, 1},
			["description"] = [[
A decimal value representing a percentage of internal fuel remaining before
the aircraft starts considering to air-2-air refuel.]],
		},
	})
end

local function calc_reserve(data, acdesc)
	if data.reservefuel ~= 0 then
		return
	end

	data.reservefuel = acdesc.Kmax * RESERVETIME
end

local function calc_cruise(data, acdesc)
	if data.cruisespeed ~= 0 then
		return
	end

	local ratio = 0.525
	local speed = acdesc.speedMax0 or acdesc.speedMax

	if acdesc.Kab == nil or acdesc.Kab == 0 then
		ratio = 0.75
	end

	data.cruisespeed = speed * ratio
end

local function modify_actions(data)
	if data.attributes["Refuelable"] == true then
		data.goals["Refuel"] = 1
		data.actions["A2A_Refuel"] = 2
	end
end

function CheckAircraft:check(data)
	if adtypes[data.objtype] == nil then
		return true
	end

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

	local actype = data.tpldata[1].data.units[1].type
	local acdesc = Unit.getDescByName(actype)

	calc_reserve(data, acdesc)
	calc_cruise(data, acdesc)
	utils.mergetables(data.attributes, airframe_attr_fixups[actype])
	modify_actions(data)
	return true
end

return CheckAircraft
