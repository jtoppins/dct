--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a side's strategic theater commander.
--]]

local utils      = require("libs.utils")
local containers = require("libs.containers")
local enum       = require("dct.enum")
local dctutils   = require("dct.utils")
local Mission    = require("dct.ai.Mission")
local Stats      = require("dct.libs.Stats")
local Command    = require("dct.Command")
local Logger     = dct.Logger.getByName("Commander")

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
local Commander = require("libs.namedclass")("Commander")
function Commander:__init(theater, side)
	self.owner        = side
	self.missionstats = Stats(genstatids())
	self.missions     = {}
	self.tgtlist      = {}
	self.aifreq       = 2*60 -- 2 minutes in seconds

	-- Cache valid mission IDs in random order
	self.missionIds = {}
	for i = 0, 63 do
		table.insert(self.missionIds, math.random(#self.missionIds + 1), i)
	end

	theater:queueCommand(120, Command(
		"Commander("..tostring(self.owner)..").startIADS",
		self.startIADS, self))
	theater:queueCommand(self.aifreq, Command(
		"Commander("..tostring(self.owner)..").update",
		self.update, self))
	theater:getAssetMgr():addObserver(self.assethandler, self,
		"Commander("..tostring(self.owner)..").assethandler")
end

local function handle_asset_dead(cmdr, event)
	cmdr.tgtlist[event.initiator.name] = nil
end

local function handle_asset_add(cmdr, event)
	local asset = event.initiator

	if dctutils.isenemy(cmdr.owner, asset.owner) and
	   enum.assetClass.STRATEGIC[asset.type] ~= nil then
		cmdr.tgtlist[asset.name] = asset.type
	end
end

function Commander:assethandler(event)
	local handlers = {
		[enum.event.DCT_EVENT_DEAD] = handle_asset_dead,
		[enum.event.DCT_EVENT_ADD_ASSET] = handle_asset_add,
	}

	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

function Commander:startIADS()
	self.IADS = require("dct.systems.IADS")(self)
end

function Commander:update(time)
	for _, mission in pairs(self.missions) do
		mission:update(time)
	end
	return self.aifreq
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
	local theater = dct.Theater.singleton()
	local theaterUpdate = {}
	local tks, start

	theaterUpdate.friendly = {}
	tks, start = theater:getTickets():get(self.owner)
	theaterUpdate.friendly.str = math.floor((tks / start)*100)
	theaterUpdate.enemy = {}
	theaterUpdate.enemy.sea = 50
	theaterUpdate.enemy.air = 50
	theaterUpdate.enemy.elint = 50
	theaterUpdate.enemy.sam = 50
	tks, start = theater:getTickets():get(dctutils.getenemy(self.owner))
	theaterUpdate.enemy.str = math.floor((tks / start)*100)
	theaterUpdate.missions = self.missionstats:getStats()
	for k,v in pairs(theaterUpdate.missions) do
		if v == 0 then
			theaterUpdate.missions[k] = nil
		end
	end
	return theaterUpdate
end

local invalidXpdrTbl = {
	["7700"] = true,
	["7600"] = true,
	["7500"] = true,
	["7400"] = true,
}

--[[
-- Generates a mission id as well as generating IFF codes for the
-- mission (in octal).
--
-- Returns: a table with the following:
--   * id (string): is the mission ID
--   * m1 (number): is the mode 1 IFF code
--   * m3 (number): is the mode 3 IFF code
--  If 'nil' is returned no valid mission id could be generated.
--]]
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

--[[
-- recommendMission - recommend a mission type given a unit type
-- unittype - (string) the type of unit making request requesting
-- return: mission type value
--]]
function Commander:recommendMissionType(allowedmissions)
	local assetfilter = {}

	for _, v in pairs(allowedmissions) do
		utils.mergetables(assetfilter, enum.missionTypeMap[v])
	end

	local pq = heapsort_tgtlist(self.tgtlist, assetfilter, self.owner)

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
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local pq = heapsort_tgtlist(self.tgtlist,
		enum.missionTypeMap[missiontype], self.owner)

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

--[[
-- return the Mission object identified by the id supplied.
--]]
function Commander:getMission(id)
	return self.missions[id]
end

--[[
-- return the number of missions that can be assigned per given type
--]]
function Commander:getAvailableMissions(missionTypes)
	local assetmgr = dct.theater:getAssetMgr()

	-- map asset types to the given mission type names
	local assetTypeMap = {}
	for missionTypeName, missionTypeId in pairs(missionTypes) do
		for assetType, _ in pairs(enum.missionTypeMap[missionTypeId]) do
			assetTypeMap[assetType] = missionTypeName
		end
	end

	local counts = {}

	-- build a user-friendly mapping using the mission type names as keys
	for name, assetType in pairs(self.tgtlist) do
		local asset = assetmgr:getAsset(name)
		if not asset:isDead() and not asset:isTargeted(self.owner) then
			local missionType = assetTypeMap[assetType]
			if missionType ~= nil then
				counts[missionType] = counts[missionType] or 0
				counts[missionType] = counts[missionType] + 1
			end
		end
	end

	return counts
end

--[[
-- start tracking a given mission internally
--]]
function Commander:addMission(mission)
	self.missions[mission:getID()] = mission
	self.missionstats:inc(mission.type)
end

--[[
-- remove the mission identified by id from the commander's tracking
--]]
function Commander:removeMission(id)
	local mission = self.missions[id]
	self.missions[id] = nil
	self.missionstats:dec(mission.type)
end

function Commander:getAssigned(asset)
	local msn = self.missions[asset.missionid]

	if msn == nil then
		asset.missionid = enum.misisonInvalidID
		return nil
	end

	local member = msn:isMember(asset.name)
	if not member then
		asset.missionid = enum.misisonInvalidID
		return nil
	end
	return msn
end

return Commander
