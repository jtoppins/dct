--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common functions to convert data to human readable formats
--]]

require("math")
local utils    = require("libs.utils")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")

local human = {}

local markindex = 10
function human.getMarkID()
	markindex = markindex + 1
	return markindex
end
local marks = {}

-- enemy air superiroty as defined by the US-DOD is
--  'incapability', 'denial', 'parity', 'superiority',
--  'supremacy' - this is simply represented by a number
--  which can then be mapped to a given word
function human.airthreat(value)
	assert(value >= 0 and value <= 100, "value error: value out of range")
	if value >= 0 and value < 20 then
		return "incapability"
	elseif value >= 20 and value < 40 then
		return "denial"
	elseif value >= 40 and value < 60 then
		return "parity"
	elseif value >= 60 and value < 80 then
		return "superiority"
	end
	return "supremacy"
end

-- The value is a rough representation of threat level between 0
-- and 100. This is translated in to 'low', 'med', & 'high'.
function human.threat(value)
	assert(value >= 0 and value <= 100, "value error: value out of range")
	if value >= 0 and value < 30 then
		return "low"
	elseif value >= 30 and value < 70 then
		return "medium"
	end
	return "high"
end

function human.strength(value)
	if value == nil then
		return "Unknown"
	end

	if value < 25 then
		return "Critical"
	elseif value >= 25 and value < 75 then
		return "Marginal"
	elseif value >= 75 and value < 125 then
		return "Nominal"
	end
	return "Excellent"
end

function human.missiontype(mtype)
	return assert(utils.getkey(enum.missionType, mtype),
		"no name found for mission type ("..mtype..")")
end

function human.locationhdr(msntype)
	local hdr = "Target AO"
	if msntype == enum.missionType.CAS or
		msntype == enum.missionType.CAP then
		hdr = "Station AO"
	end
	return hdr
end

function human.drawTargetIntel(msn, grpid, readonly)
	local tgtinfo = msn:getTargetInfo()
	local degpos = dctutils.degrade_position(tgtinfo.location,
		tgtinfo.intellvl)
	local msg = "desc: "..tostring(tgtinfo.description).."\n"..
		string.format("status: %d%% complete\nthreats: TODO",
			tgtinfo.status)
	local markId = human.getMarkID()
	trigger.action.markToGroup(markId,
		"TGT: "..tgtinfo.callsign,
		degpos,
		grpid,
		readonly,
		msg)
	if marks[grpid] == nil then
		marks[grpid] = {}
	end
	marks[grpid][msn.id] = markId
end

function human.removeIntel(msn, grpid)
	if marks[grpid] ~= nil and marks[grpid][msn.id] ~= nil then
		trigger.action.removeMark(marks[grpid][msn.id])
		marks[grpid][msn.id] = nil
	end
end

return human
