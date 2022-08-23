--- SPDX-License-Identifier: LGPL-3.0

local containers = require("libs.containers")
local class      = require("libs.namedclass")
local dctenum    = require("dct.enum")
local Mission    = require("dct.libs.Mission")
local WS         = require("dct.ai.worldstate")

-- Create an air strike mission

local AirStrike = class("Air Strike", Mission)
function AirStrike:__init(cmdr)
	Mission(cmdr, dctenum.missionType.STRIKE, goalq, timeout)
end

local function add_target(pq, tgt, owner, filterlist)
	if tgt == nil then
		return
	end

	if tgt.ignore or filterlist[tgt.type] == nil then
		return
	end

	if tgt:isDead() or tgt:isTargeted(owner) then
		return
	end

	pq:push(tgt:getPriority(owner), tgt)
end

local function heapsort_tgtlist(tgtlist, filterlist, owner)
	local pq = containers.PriorityQueue()
	local assetmgr = dct.Theater.singleton():getAssetMgr()

	if type(filterlist) == "table" then
		filterlist = filterlist
	elseif type(filterlist) == "number" then
		local typenum = filterlist
		filterlist = {}
		filterlist[typenum] = true
	else
		assert(false, "value error: filterlist must be a number or table")
	end

	-- priority sort target list
	for tgtname, _ in pairs(tgtlist) do
		local tgt = assetmgr:getAsset(tgtname)
		add_target(pq, tgt, owner, filterlist)
	end

	return pq
end

--- Creates a new mission where the target conforms to the mission type
-- specified and is of the highest priority. The Commander will track
-- the mission and handling tracking which asset is assigned to the
-- mission.
--
-- @param grpname name of the commander's asset that is assigned to take
--   out the target.
-- @param missiontype type of mission which defines the type of target
--   that will be looked for.
--
-- @return Mission object or nil if no target can be found which
--   meets the mission criteria
function Commander:requestMission(grpname, missiontype)
	local assetmgr = require("dct.Theater").singleton():getAssetMgr()
	local pq = heapsort_tgtlist(self.tgtlist,
		dctenum.missionTypeMap[missiontype], self.owner)

	-- if no target, there is no mission to assign so return back
	-- a nil object
	local tgt = pq:pop()
	if tgt == nil then
		return nil
	end
	Logger:debug("requestMission() - tgt name: '%s'; isTargeted: %s",
		tgt.name, tostring(tgt:isTargeted()))

	local plan = { require("dct.ai.actions.KillTarget")(tgt) }
	local mission = Mission(self, missiontype, tgt, plan)
	mission:addAssigned(assetmgr:getAsset(grpname))
	self:addMission(mission)

	Logger:debug("requestMission() - assigned target '%s' to "..
		"mission %d (codename: %s)", tgt.name,
		mission.id, tgt.codename)

	return mission
end
