--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a side's strategic theater commander.
--]]

local class      = require("libs.class")
local utils      = require("libs.utils")
local containers = require("libs.containers")
local enum       = require("dct.enum")
local dctutils   = require("dct.utils")
local Mission    = require("dct.Mission")
local Stats      = require("dct.Stats")

local function heapsort_tgtlist(assetmgr, owner, filterlist)
	local tgtlist = assetmgr:getTargets(owner, filterlist)
	local pq = containers.PriorityQueue()

	-- priority sort target list
	for tgtname, _ in pairs(tgtlist) do
		local tgt = assetmgr:getAsset(tgtname)
		if tgt ~= nil and not tgt:isDead() and not tgt:isTargeted() then
			pq:push(tgt:getPriority(), tgt)
		end
	end

	return pq
end

local function genstatids()
	local tbl = {}

	for k,v in pairs(enum.missionType) do
		table.insert(tbl, {v, 0, k})
	end
	return tbl
end

--[[
-- For now the commander is only concerned with flight missions
--]]
local Commander = class()

function Commander:__init(coalition, theater)
	self.owner        = coalition
	self.theater      = theater
	self.missionstats = Stats(genstatids())
	self.missions     = {}
	self.assigned     = {}
end

--[[
-- TODO: complete this, the enemy information is missing
-- What does a commander need to track for theater status?
--   * the UI currently defines these items that need to be "tracked":
--     - Sea - representation of the opponent's sea control
--     - Air - representation of the opponent's air control
--     - ELINT - representation of the opponent's ability to detect
--     - SAM - representation of the opponent's ability to defend
--     - current active air mission types
--]]
function Commander:getTheaterUpdate()
	--local enemystats = self.theater:getTargetStats(self.owner)
	local theaterUpdate = {}

	theaterUpdate.enemy = {}
	theaterUpdate.enemy.sea = 50
	theaterUpdate.enemy.air = 50
	theaterUpdate.enemy.elint = 50
	theaterUpdate.enemy.sam = 50
	theaterUpdate.missions = self.missionstats:getStats()
	for k,v in pairs(theaterUpdate.missions) do
		if v == 0 then
			theaterUpdate.missions[k] = nil
		end
	end
	return theaterUpdate
end

--[[
-- recommendMission - recommend a mission type given a unit type
-- unittype - (string) the type of unit making request requesting
-- return: mission type value
--]]
function Commander:recommendMissionType(unittype)
	local assetfilter = {}
	local allowedmissions = self.theater:getATORestrictions(self.owner,
		unittype)

	for _, v in pairs(allowedmissions) do
		utils.mergetables(assetfilter, enum.missionTypeMap[v])
	end

	local pq = heapsort_tgtlist(self.theater:getAssetMgr(),
		self.owner, assetfilter)

	local tgt = pq:pop()
	if tgt == nil then
		return nil
	end
	return dctutils.assettype2mission(tgt.type)
end

--[[
-- requestMission - get a new mission
--
-- Creates a new mission where the target conforms to the mission type
-- specified and is of the highest priority. The Commander will track
-- the mission and handling tracking which asset is assigned to the
-- mission.
--
-- grpname - the name of the commander's asset that is assigned to take
--   out the target.
-- missiontype - the type of mission which defines the type of target
--   that will be looked for.
--
-- return: a Mission object or nil if no target can be found which
--   meets the mission criteria
--]]
function Commander:requestMission(grpname, missiontype)
	local pq = heapsort_tgtlist(self.theater:getAssetMgr(),
		self.owner, enum.missionTypeMap[missiontype])

	-- if no target, there is no mission to assign so return back
	-- a nil object
	local tgt = pq:pop()
	if tgt == nil then
		return nil
	end

	local mission = Mission(self, missiontype, grpname, tgt:getName())
	self:addMission(mission)
	return mission
end

--[[
-- return the Mission object identified by the id supplied.
--]]
function Commander:getMission(id)
	return self.missions[id]
end

--[[
-- return the mission assigned to the given asset name (grpname)
--]]
function Commander:getAssigned(grpname)
	local id = self.assigned[grpname]
	if id == nil then
		return nil
	end
	return self.missions[id]
end

function Commander:getAsset(name)
	return self.theater:getAssetMgr():getAsset(name)
end

--[[
-- remove the mission identified by id from the commander's tracking
--]]
function Commander:removeMission(id)
	local mission = self.missions[id]
	self.missions[id] = nil
	self.assigned[mission.assigned] = nil
	self.missionstats:dec(mission.type)
end

function Commander:addMission(mission)
	self.missions[mission:getID()]  = mission
	self.assigned[mission.assigned] = mission:getID()
	self.missionstats:inc(mission.type)
end

return Commander
