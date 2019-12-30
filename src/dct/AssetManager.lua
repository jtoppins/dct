--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

-- TODO: Idea, a "TRANSPORT" asset could represent a helo transport
--   mission such as delivering special forces to a location where
--   they then act as a JTAC.
--
-- TODO: in AssetManager define an "AirSpace" asset class that can be
--   assigned to commanders, this type of asset can be used to define
--   CAP sorties, DCA patrols, and OCA sweeps.
--

local class    = require("libs.class")
local enum     = require("dct.enum")
local Logger   = require("dct.Logger").getByName("AssetManager")
local Command  = require("dct.Command")
local Stats    = require("dct.Stats")

local enemymap = {
	[coalition.side.NEUTRAL] = false,
	[coalition.side.BLUE]    = coalition.side.RED,
	[coalition.side.RED]     = coalition.side.BLUE,
}

local AssetCheckCmd = class(Command)

function AssetCheckCmd:__init(assetmgr)
	self._assetmgr = assetmgr
end

function AssetCheckCmd:execute(time)
	self._assetmgr:checkAssets(time)
	return nil
end

local ASSET_CHECK_DELAY = 30  -- seconds

local substats = {
	["ALIVE"]   = 1,
	["NOMINAL"] = 2,
}

local statids = nil

local function genstatids()
	if statids ~= nil then
		return statids
	end

	local tbl = {}

	for k,v in pairs(enum.assetType) do
		for k2,v2 in pairs(substats) do
			table.insert(tbl, { v.."."..v2, 0, k.."."..k2 })
		end
	end
	statids = tbl
	return tbl
end

local AssetManager = class()

function AssetManager:__init(theater)
	-- back reference to theater class
	self._theater = theater

	-- variables to track the checking of assets' death goals
	self._checkqueued = false
	self._lastchecked = 0

	-- The master list of assets, regardless of side, indexed by name.
	-- Means Asset class names must be globally unique.
	self._assetset = {}

	-- The per side lists to maintain "short-cuts" to assets that
	-- belong to a given side and are alive or dead.
	-- These lists are simply asset names as keys with values of
	-- asset type. To get the actual asset object we need to lookup
	-- the name in a master asset list.
	self._sideassets = {
		[coalition.side.NEUTRAL] = {
			["assets"] = {},
			["stats"]  = Stats(genstatids()),
		},
		[coalition.side.RED]     = {
			["assets"] = {},
			["stats"]  = Stats(genstatids()),
		},
		[coalition.side.BLUE]    = {
			["assets"] = {},
			["stats"]  = Stats(genstatids()),
		},
	}

	-- keeps track of static/unit/group names to asset objects,
	-- remember all spawned Asset classes will need to register the names
	-- of their DCS objects with 'something', this will be the something.
	self._object2asset = {}

	self._theater:registerHandler(self.onDCSEvent, self)
	self:queueCheckAsset()
end

function AssetManager:remove(asset)
	assert(asset ~= nil, "value error, asset object must be provided")

	local isstrat = enum.assetClass.STRATEGIC[asset["type"]] or false

	-- remove asset from master asset list if the asset is not a
	--  strategic target. This supports the feature where dead
	--  strategic assets can be spawned in as dead.
	if not isstrat then
		self._assetset[asset:getName()] = nil
	end

	-- remove asset name from per-side asset list
	self._sideassets[asset.owner].assets[asset:getName()] = nil
	self._sideassets[asset.owner].stats:dec(asset.type.."."..substats.ALIVE)

	-- remove asset object names from name list
	for _, objname in pairs(asset:getObjectNames()) do
		self._object2asset[objname] = nil
	end
end

function AssetManager:add(asset)
	assert(asset ~= nil, "value error, asset object must be provided")

	-- add asset to master list
	assert(self._assetset[asset:getName()] == nil, "asset name ('"..
		asset:getName().."') already exists")
	self._assetset[asset:getName()] = asset

	-- add asset to approperate side lists
	if not asset:isDead() then
		self._sideassets[asset.owner].assets[asset:getName()] = asset.type
		self._sideassets[asset.owner].stats:inc(asset.type.."."..
			substats.ALIVE)

		-- read Asset's object names and setup object to asset mapping
		-- to be used in handling DCS events and other uses
		for _, objname in pairs(asset:getObjectNames()) do
			self._object2asset[objname] = asset:getName()
		end
	end
end

function AssetManager:getAsset(name)
	return self._assetset[name]
end

function AssetManager:getStats(side)
	return self._sideassets[side].stats
end

--[[
-- getTargets - returns the names of the assets conforming to the asset
--   type filter list, the caller must use AssetManager:get() to obtain
--   the actual asset object.
-- assettypelist - a list of asset types wanted to be included
-- requestingside - the coalition requesting the target list, thus
--     we need to return their enemy asset list
-- Return: return a table that lists the asset names that fit the
--    filter list requested
--]]
function AssetManager:getTargets(requestingside, assettypelist)
	local enemy = enemymap[requestingside]
	local tgtlist = {}
	local filterlist

	-- some sides may not have enemies, return an empty target list
	-- in this case
	if enemy == false then
		return {}
	end

	if type(assettypelist) == "table" then
		filterlist = assettypelist
	elseif type(assettypelist) == "number" then
		filterlist = {}
		filterlist[assettypelist] = true
	else
		assert(false, "value error: assettypelist must be a number or table")
	end

	for tgtname, tgttype in pairs(self._sideassets[enemy].assets) do
		if filterlist[tgttype] ~= nil then
			tgtlist[tgtname] = tgttype
		end
	end
	return tgtlist
end

--[[
-- Queue up a delayed command to perform the time consuming task
-- of checking if an asset's dead goal has been met.
-- We should delay processing for at least 10 seconds to accumulate
-- other possible hits, like a rocket attack. If a check is already
-- outstanding we should not request another until the queued check
-- has been processed.
--
-- NOTE: This might be a problem resulting in a race condition
-- manifesting in what appears to be dropping asset events, the
-- solution is to queue a command for each asset. This could be
-- handled by queuing a delayed command check (with the Theater)
-- and then an internal per asset queue to check each asset.
-- TODO: we could implement a way of detecting this by each
-- asset tracking when it was last hit and when it was last checked.
--]]
function AssetManager:queueCheckAsset()
	if self._checkqueued then
		Logger:debug("queueCheckAsset() - already queued, ignoring")
		return
	end
	self._theater:queueCommand(ASSET_CHECK_DELAY, AssetCheckCmd(self))
	self._checkqueued = true
end

--[[
-- Check all assets to see if their death goal has been met.
--
-- *Note:* We just do the simple thing, check all assets.
-- Nothing complicated for now.
--]]
function AssetManager:checkAssets(time)
	local force = false
	if (time - self._lastchecked) > 600 then
		force = true
	end

	local perftime_s = timer.getTime()
	self._lastchecked = time
	local cnt = 0

	for _, asset in pairs(self._assetset) do
		cnt = cnt + 1
		asset:checkDead(force)
		if asset:isDead() then
			self:remove(asset)
		end
	end
	self._checkqueued = false
	Logger:debug("checkAssets() - runtime: "..
		tostring(timer.getTime()-perftime_s)..
		" seconds, forced: "..tostring(force)..
		", assets checked: "..tostring(cnt))
end

function AssetManager:onDCSEvent(event)
	local relevents = {
		[world.event.S_EVENT_HIT] = true,
		[world.event.S_EVENT_DEAD] = true,
	}
	local objcat = {
		[Object.Category.UNIT]   = true,
		[Object.Category.STATIC] = true,
	}

	if not relevents[event.id] then
		return
	end

	if not event.initiator or
	   objcat[event.initiator:getCategory()] == nil then
		return
	end

	local obj = event.initiator
	local name = obj:getName()
	if obj:getCategory() == Object.Category.UNIT then
		name = obj:getGroup():getName()
	end

	local asset = self._object2asset[name]
	if asset == nil then
		return
	end
	asset = self._assetset[asset]
	if asset == nil then
		return
	end

	asset:onDCSEvent(event)
	self:queueCheckAsset()
end

function AssetManager:marshal(ignoredirty)
	-- TODO: marshal assets into a table and return to the caller
end

function AssetManager:unmarshal(data)
	-- TODO: read in and create all assets that were saved off
end

return AssetManager
