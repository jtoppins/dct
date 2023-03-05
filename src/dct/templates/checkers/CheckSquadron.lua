-- SPDX-License-Identifier: LGPL-3.0

--- @classmod dct.templates.checkers.CheckSquadron

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")

local issquadron = {
	[dctenum.assetType.SQUADRON] = true,
}

local isaircraft = {
	[Unit.Category.AIRPLANE] = true,
	[Unit.Category.HELICOPTER] = true,
}

local task2mission = {
	["SEAD"] = dctenum.missionType.SEAD,
	["ANTISHIP STRIKE"] = dctenum.missionType.ANTISHIP,
	["AWACS"] = dctenum.missionType.AWACS,
	["CAS"] = dctenum.missionType.CAS,
	["CAP"] = dctenum.missionType.CAP,
	["PINPOINT STRIKE"] = dctenum.missionType.STRIKE,
	["ESCORT"] = dctenum.missionType.ESCORT,
	["FIGHTER SWEEP"] = dctenum.missionType.SWEEP,
	["GROUND ATTACK"] = dctenum.missionType.STRIKE,
	["INTERCEPT"] = dctenum.missionType.INTERCEPT,
	["AFAC"] = dctenum.missionType.JTAC,
	["RECONNAISSANCE"] = dctenum.missionType.RECON,
	["REFUELING"] = dctenum.missionType.TANKER,
	["RUNWAY ATTACK"] = dctenum.missionType.OCA,
	["TRANSPORT"] = dctenum.missionType.TRANSPORT,
}

local function process_group(grp, data)
	if isaircraft[grp.category] == nil then
		return false
	end

	local msntype = task2mission[string.upper(grp.data.task)]

	if msntype then
		data.ato[msntype] = true
	end

	for _, unit in ipairs(grp.data.units or {}) do
		data.airframes[unit.type] = true
	end
	return true
end

local function check_ato(data)
	local msnlist = {}

	for _, msntype in pairs(data.ato) do
		local msnstr = string.upper(msntype)
		if type(msntype) ~= "string" or
		   dctenum.missionType[msnstr] == nil then
			return false, "ato",
				"invalid mission type: "..tostring(msnstr)
		end
		msnlist[dctenum.missionType[msnstr]] = true
	end
	data.ato = msnlist
	return true
end

local CheckSquadron = class("CheckSquadron", Check)
function CheckSquadron:__init()
	Check.__init(self, "Squadron", {
		["airframes"] = {
			["nodoc"] = true,
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
The airframe type used is defined in the squadron's .stm file.]],
		},
		["players_only"] = {
			["nodoc"] = true,
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
If true it is expected only players are members of the squadron and no
template data will be associated with the squadron.]],
		},
		["ato"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
The allowed mission types the squadron can fly. See the
[User Interface](#user-interfaceui) section for details on how this
attribute is defined. This table can be auto-generated if the squadron
defines aircraft templates.]],
		},
		["airframe_max"] = {
			["default"] = -1,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Maximum number of airframes the squadron can have, -1 unlimited.]],
		},
		["airframe_start"] = {
			["default"] = -1,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Starting number of aircraft the squadron has, -1 unlimited.]],
		},
		["airframe_cooldown"] = {
			["default"] = 600,
			["type"] = Check.valuetype.INT,
			["description"] = [[
The base cooldown time, in seconds, before an aircraft returning from a
mission is placed on the available list.]],
		},
		["airframe_damage_multiplier"] = {
			["default"] = 10,
			["type"] = Check.valuetype.INT,
			["description"] = [[
The multiplier applied to the cooldown time if the returning aircraft
is damaged. The formula used is:
`(1 + [normalized_damage * damage_multiplier]) * cooldown`]],
		},
		["airframe_damage_threshold"] = {
			["nodoc"] = false,
			["default"] = .6,
			["type"] = Check.valuetype.RANGE,
			["values"] = {0, 1},
			["description"] = [[
The normalized damage allowed to be taked by a returning aircraft before
it is considered a total loss reducing the available pool permanently.]]
		},
		["all_players"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
If true auto associate all player slots at the airbase with the squadron.]],
		},
		["skill"] = {
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = AI.Skill,
			["default"] = "average",
			["description"] = [[
Defines the initial average starting skill of the squadron. Squadrons can
increase in skill as missions are successfully completed. Losses may decrease
the average skill of the squadron.]],
		},
	}, [[Squadrons can come in three forms players only, mixed, and
ai only. Squadrons that only have players are not required to define
templates.]])
end

function CheckSquadron:check(data)
	if issquadron[data.objtype] == nil then
		return true
	end

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

	ok, key, msg = check_ato(data)
	if not ok then
		return ok, key, msg
	end

	data.rename = false
	data.airframes = {}

	if data.tpldata == nil then
		data.notpldata = true
		data.players_only = true
	else
		local cnt = 0
		for _, grp in ipairs(data.tpldata or {}) do
			if process_group(grp, data) then
				cnt = cnt + 1
			end
		end

		if cnt <= 0 then
			return false, "tpldata", "no valid templates defined"
		end
	end

	if data.attackrange == dctenum.DEFAULTRANGE then
		data.attackrange = 555600 -- 300 NM
	end

	return true
end

return CheckSquadron
