-- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")

local RESERVETIME = 20 * 60 -- 20 minutes
local adtypes = {
	[dctenum.assetType.AIRPLANE] = true,
	[dctenum.assetType.HELO]     = true,
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
			["default"] = 0.9,
			["type"] = Check.valuetype.INT,
			["description"] = [[
A decimal value [0,1] representing a percentage of internal fuel remaining
an aircraft with greater than this fuel is considered to have fuel.]],
		},
	})
end

function CheckAircraft:check(data)
	if adtypes[data.objtype] == nil then
		return true
	end

	local ok, key, msg = Check.check(self, data)

	if not ok then
		return ok, key, msg
	end

	if data.reservefuel == 0 or data.cruisespeed == 0 then
		-- TODO: need a better way to figure out the type of aircraft
		-- in the template, this basically forces single aircraft
		-- groups.
		local actype = data.tpldata[1].data.units[1].type
		local acdesc = Unit.getDescByName(actype)

		if data.reservefuel == 0 then
			data.reservefuel = acdesc.Kmax * RESERVETIME
		end

		if data.cruisespeed == 0 then
			local ratio = 0.525

			if acdesc.Kab == 0 then
				ratio = 0.75
			end

			data.cruisespeed = acdesc.speedMax0 * ratio
		end
	end

	return true
end

return CheckAircraft
