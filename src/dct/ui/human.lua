--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common functions to convert data to human readable formats
--]]

local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local settings = _G.dct.settings

local human = {}

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

-- TODO: this function is the exact same as utils.getkey(t,v)
-- remove this and utilize getkey() instead
function human.missiontype(mtype)
	for name, val in pairs(enum.missionType) do
		if val == mtype then
			return name
		end
	end
	assert(false, "no name found for mission type ("..mtype..")")
end


function human.locationhdr(msntype)
	local hdr = "Target AO"
	if msntype == enum.missionType.CAS or
		msntype == enum.missionType.CAP then
		hdr = "Station AO"
	end
	return hdr
end

function human.grid2actype(actype, location, precision)
	local fmt = settings.acgridfmt[actype]
	precision = precision or 3
	if fmt == nil then
		fmt = dctutils.posfmt.DMS
	end
	return dctutils.fmtposition(location, precision, fmt)
end

return human
