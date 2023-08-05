-- SPDX-License-Identifier: LGPL-3.0

--- common functions to convert data to human readable formats

require("math")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Mission  = require("dct.libs.Mission")
local WS       = require("dct.assets.worldstate")

local human = {}

--- Filter out facts that are not considered targets.
local function istarget(owner)
	return function (fact)
		if fact.type == WS.Facts.factType.CHARACTER and
		   fact.objtype == dctenum.objtype.AGENT and
		   dctutils.isenemy(fact.owner.value, owner) and
		   fact.object.confidence > 0 and fact.position and
		   (fact.position.confidence * dctutils.INTELMAX) > 3 then
			return true
		end
		return false
	end
end

--- Filter out facts that are not considered threats.
local function isthreat(owner)
	return function (fact)
		if fact.type == WS.Facts.factType.CHARACTER and
		   fact.objtype == dctenum.objtype.AGENT and
		   dctutils.isenemy(fact.owner.value, owner) and
		   fact.object.confidence == 0 then
		   return true
		end
		return false
	end
end

--- enemy air superiority as defined by the US-DOD is
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

--- The value is a rough representation of threat level between 0
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

function human.relationship(side1, side2)
	if side1 == side2 then
		return "Friendly"
	elseif dctutils.getenemy(side1) == side2 then
		return "Hostile"
	else
		return "Neutral"
	end
end

-- TODO: this needs to be refined. It needs to be able to handle
-- different character types. Actually it really only makes sense
-- to support Agents, the trouble is things like factories and
-- oil storage should be able to display the coordinates of
-- individual statics and scenery.
--
-- The format of the output is:
-- #. <coords> - <displayname> (<status:operational|damaged>)
function human.mission_detail_facts(msn, filter, gridfmt)
	local facts = {}

	for _, fact in msn:iterateFacts(filter) do
		table.insert(facts, fact)
	end

	if next(facts) == nil then
		return nil
	end

	local result = ""
	for k, fact in ipairs(facts) do
		local health = string.lower(utils.getkey(WS.Health,
					fact.status.value))
		local intel = fact.position.confidence * dctutils.INTELMAX
		local line = string.format("%d. %s - %s (%s)\n",
			k,
			dctutils.fmtposition(fact.position.value,
					     intel, gridfmt),
			tostring(fact.displayname),
			health)
		result = result..line
	end

	return result
end

--- Print all the assets assigned to the Mission(msn).
--
-- @param msn the mission to print the assets assigned
-- @return string listing all the assets assigned
function human.mission_assigned(player)
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local msn = player:getMission()
	local assets = {}

	for name, _ in msn:iterateAssigned() do
		local asset = assetmgr:getAsset(name)

		if asset and asset.type == dctenum.assetType.PLAYER then
			table.insert(assets, "P: "..
				asset:getDescKey("displayname"))
		elseif asset then
			table.insert(assets, "AI: "..
				asset:getDescKey("displayname"))
		end
	end

	return table.concat(assets, "\n")
end

--- Format location of mission according to the grid format
-- the player object wants.
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_location(player)
	local msn = player:getMission()

	return dctutils.fmtposition(msn:getDescKey("location"),
				    msn:getDescKey("intel"),
				    player:getDescKey("gridfmt"))
end

--- Print target details. Targets are found by iterating over the
-- mission facts looking for character facts with a confidence
-- greater then zero.
--
-- Format:
-- #. <coords> - <displayname> (<status:operational|damaged>)
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_targets(player)
	local result = human.mission_detail_facts(
		player:getMission(), istarget(player.owner),
		player:getDescKey("gridfmt"))

	if result == nil then
		return "No detailed target info."
	end

	return result
end

--- Print threat details.
-- Format:
-- #. <coords> - <displayname> (<status:operational|damaged>)
--
-- @param player an Agent object representing a player
-- @return string
function human.mission_threats(player)
	local result = human.mission_detail_facts(
		player:getMission(), isthreat(player.owner),
		player:getDescKey("gridfmt"))

	if result == nil then
		return "No known threats."
	end

	return result
end

function human.mission_remarks(player)
	local remarks = player:getMission():getDescKey("remarks")

	if remarks == nil then
		return "None."
	end

	return remarks
end

-- TODO: missions can have a tactical frequency assigned, also
-- if a mission has supporting missions a "package" frequency
-- could be assigned. Finally if a mission knows about any
-- supporting assets in the region they could be included.
-- This will be communicated via a mission description table
-- entry, "comms", of the format:
-- mission.desc.comms = {
--     ["flight"] = xxxxxxxxx, -- where the frequency is in hertz
--     ["package"] = x,
--     ["jtac"] = y,
--     -- common frequencies defined at the theater level
--     ["tac1"] = z,
--     ["guard"] = g,
--     -- supporting missions
--     ["tanker"] = a,
--     ["awacs"] = u,
-- }
--
-- Also support defining the IFF codes the player should be
-- using.
function human.mission_commsplan(--[[player]])
	return "Not Implemented"

--[[
local invalidXpdrTbl = {
	["7700"] = true,
	["7600"] = true,
	["7500"] = true,
	["7400"] = true,
}

-- TODO: move this to the human module as IFF codes can be generated from
-- the mission id and the player's join number.
--- Generates a mission id as well as generating IFF codes for the
-- mission (in octal).
--
-- Returns: a table with the following:
--   * id (string): is the mission ID
--   * m1 (number): is the mode 1 IFF code
--   * m3 (number): is the mode 3 IFF code
--  If 'nil' is returned no valid mission id could be generated.
function Commander:genMissionCodes(msntype)
	local missionId, fmtId
	local digit1 = enum.squawkMissionType[msntype]
	for _, id in ipairs(self.missionIds) do
		fmtId = string.format("%01o%02o0", digit1, id)
		if invalidXpdrTbl[fmtId] == nil and self:getMission(fmtId) == nil then
			missionId = id
			break
		end
	end
	assert(missionId ~= nil, "cannot generate mission: no valid ids left")
	local m1 = (8*digit1)+(enum.squawkMissionSubType[msntype] or 0)
	local m3 = (512*digit1)+(missionId*8)
	return { ["id"] = fmtId, ["m1"] = m1, ["m3"] = m3, }
end
--]]
end

--- Generate mission description text from the supplied information
--
-- Replacement text support in briefing descriptions
-- %LOCATIONMETHOD% - a simple little text blurb on how the target was
--                    discovered, not terribly important.
-- %LOCATION% - per player formatted location information
-- %TARGETS% - list of specific targets if intel is high enough precision
--             coordinates will be provided
function human.mission_description(player)
	local msn = player:getMission()
	local description = msn:getDescKey("description")
	local locationmethod = msn:getDescKey("locationmethod")
	local msg

	msg = dctutils.interp(description, {
		["LOCATIONMETHOD"] = locationmethod,
		["LOCATION"] = human.mission_location(player),
		["TARGETS"] = human.mission_targets(player),
	})

	return msg
end

--- Generate the mission overview. This also doubles as the mission
-- status when players request status about the mission they are
-- assigned.
--
-- @param player the player agent
-- @return mission overview string
function human.mission_overview(player)
	local msn = player:getMission()
	local timer = msn:getTimer()
	local health = msn:getFact(WS.Facts.factKey.HEALTH)
	local msndata = Mission.typeData[msn.type]
	local msg = string.format("Package: #%d\n", msn:getID())..
		string.format("Mission: %s\n", msndata.name)..
		string.format("AO: %s (%s)\n",
			human.mission_location(player),
			msn:getDescKey("codename"))

	if timer then
		msg = msg..string.format("Timeout: %s (in %d mins)\n",
			os.date("%F %Rz",
				dctutils.zulutime(timer.timeoutlimit)),
			timer:remain() / 60)
	end
	msg = msg..string.format("Progress: %d%% complete",
				 health.value.value * 100)
	return msg
end

--- Generate mission briefing text for a player. The briefing is broken
-- up into sections; Overview (aka summary), Description, Threat Analysis,
-- Package Assets, and Remarks.
--
-- @param player the player agent
-- @return mission briefing string
function human.mission_briefing(player)
	if player:getMission() == nil then
		return "no mission assigned"
	end

	local msg = ""
	local sections = {
		{
			header = "### Overview",
			body = human.mission_overview(player),
		}, {
			header = "### Description",
			body = human.mission_description(player),
		}, {
			header = "### Comms Plan",
			body = human.mission_commsplan(player),
		}, {
			header = "### Threat Analysis",
			body = human.mission_threats(player),
		}, {
			header = "### Package Assets",
			body = human.mission_assigned(player),
		}, {
			header = "### Remarks",
			body = human.mission_remarks(player),
		}
	}

	for _, v in ipairs(sections) do
		msg = msg..v.header.."\n"..v.body.."\n\n"
	end
	return msg
end

return human
