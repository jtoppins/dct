--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

-- TODO: Idea, a "TRANSPORT" asset could represent a helo transport
--   mission such as delivering special forces to a location where
--   they then act as a JTAC.
--

local class    = require("libs.class")
local utils    = require("libs.utils")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local Logger   = require("dct.Logger").getByName("AssetManager")
local Command  = require("dct.Command")
local Stats    = require("dct.Stats")
local Asset    = require("dct.Asset")

local ASSET_CHECK_PERIOD = 12*60  -- seconds

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
	self._theater:queueCommand(ASSET_CHECK_PERIOD,
		Command(self.checkAssets, self))
end

function AssetManager:remove(asset)
	assert(asset ~= nil, "value error: asset object must be provided")

	local isstrat = enum.assetClass.STRATEGIC[asset["type"]] or false

	-- remove asset from master asset list if the asset is not a
	--  strategic target. This supports the feature where dead
	--  strategic assets can be spawned in as dead.
	if not isstrat then
		self._assetset[asset.name] = nil
	end

	-- remove asset name from per-side asset list
	self._sideassets[asset.owner].assets[asset.name] = nil
	self._sideassets[asset.owner].stats:dec(asset.type.."."..substats.ALIVE)

	-- remove asset object names from name list
	for _, objname in pairs(asset:getObjectNames()) do
		self._object2asset[objname] = nil
	end
end

function AssetManager:add(asset)
	assert(asset ~= nil, "value error: asset object must be provided")

	-- add asset to master list
	assert(self._assetset[asset.name] == nil, "asset name ('"..
		asset.name.."') already exists")
	self._assetset[asset.name] = asset

	-- add asset to approperate side lists
	if not asset:isDead() then
		if asset.type == enum.assetType.AIRSPACE then
			for _, side in pairs(coalition.side) do
				self._sideassets[side].assets[asset.name] = asset.type
			end
		else
			self._sideassets[asset.owner].assets[asset.name] = asset.type
		end
		self._sideassets[asset.owner].stats:inc(asset.type.."."..
			substats.ALIVE)

		-- read Asset's object names and setup object to asset mapping
		-- to be used in handling DCS events and other uses
		for _, objname in pairs(asset:getObjectNames()) do
			self._object2asset[objname] = asset.name
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
	local enemy = dctutils.getenemy(requestingside)
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
-- Check all assets to see if their death goal has been met.
--
-- *Note:* We just do the simple thing, check all assets.
-- Nothing complicated for now.
--]]
function AssetManager:checkAssets(time)
	local force = false
	if (time - self._lastchecked) > ASSET_CHECK_PERIOD then
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
	Logger:debug(string.format("checkAssets() - runtime: %4.3f ms, "..
		"forced: %s, assets checked: %d",
		(timer.getTime()-perftime_s)*1000, tostring(force), cnt))
	return ASSET_CHECK_PERIOD
end

local function handleDead(self, event)
	local obj = event.initiator

	-- TODO: I am not sure this is correct, and will at least need
	--   to be changed to handle player groups. Also, this is an
	--   group object to asset name mapping so I don't understand
	--   how a single dead event on a unit would cause the removal
	--   of something from this table.
	-- remove object from object2asset list if the event is a DEAD event
	if event.id == world.event.S_EVENT_DEAD and
	   self._object2asset[obj:getName()] ~= nil then
		self._object2asset[obj:getName()] = nil
	end
end

local handlers = {
	[world.event.S_EVENT_DEAD] = handleDead,
}

-- TODO: need to fix this handler to listen to all events given that
-- we are going to track all players
function AssetManager:onDCSEvent(event)
	local relevents = {
		[world.event.S_EVENT_BIRTH]           = true,
		[world.event.S_EVENT_ENGINE_STARTUP]  = true,
		[world.event.S_EVENT_ENGINE_SHUTDOWN] = true,
		[world.event.S_EVENT_TAKEOFF]         = true,
		[world.event.S_EVENT_LAND]            = true,
		[world.event.S_EVENT_CRASH]           = true,
		[world.event.S_EVENT_KILL]            = true,
		[world.event.S_EVENT_PILOT_DEAD]      = true,
		[world.event.S_EVENT_EJECTION]        = true,
		[world.event.S_EVENT_HIT]             = true,
		[world.event.S_EVENT_DEAD]            = true,
		--[world.event.S_EVENT_UNIT_LOST]     = true,
	}
	local objmap = {
		[world.event.S_EVENT_HIT]  = "target",
		[world.event.S_EVENT_KILL] = "target",
	}
	local objcat = {
		[Object.Category.UNIT]   = true,
		[Object.Category.STATIC] = true,
	}

	if not relevents[event.id] then
		Logger:debug("onDCSEvent - not relevent event: "..tostring(event.id))
		return
	end

	local obj = event.initiator
	if objmap[event.id] ~= nil then
		obj = event[objmap[event.id]]
	end

	if not obj or objcat[obj:getCategory()] == nil then
		Logger:debug(string.format("onDCSEvent - bad object (%s) or"..
			" category; event id: %d", tostring(obj), event.id))
		return
	end

	local name = obj:getName()
	if obj:getCategory() == Object.Category.UNIT then
		name = obj:getGroup():getName()
	end

	local asset = self._object2asset[name]
	if asset == nil then
		Logger:debug("onDCSEvent - not tracked object, obj name: "..name)
		return
	end
	asset = self:getAsset(asset)
	if asset == nil then
		Logger:debug("onDCSEvent - asset doesn't exist, name: "..name)
		return
	end

	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end

	asset:onDCSEvent(event, self._theater)
end

function AssetManager:marshal()
	local tbl = {
		["assets"] = {},
		["stats"]  = {},
	}
	local shouldmarshal = utils.shallowclone(enum.assetClass.STRATEGIC)
	shouldmarshal[enum.assetType.AIRSPACE] = true
	shouldmarshal[enum.assetType.AIRBASE]  = true


	for name, asset in pairs(self._assetset) do
		if shouldmarshal[asset.type] ~= nil then
			tbl.assets[name] = asset:marshal()
		end
	end
	for _,v in pairs(coalition.side) do
		tbl.stats[v] = self._sideassets[v].stats:marshal()
	end
	return tbl
end

function AssetManager:unmarshal(data)
	local statszero = {}
	for _,v in pairs(enum.assetType) do
		statszero[v..".1"] = 0
	end
	for side, stat in pairs(data.stats) do
		side = tonumber(side)
		self._sideassets[side].stats:unmarshal(stat)
		for k,v in pairs(statszero) do
			self._sideassets[side].stats:set(k, v)
		end
	end
	for _, assettbl in pairs(data.assets) do
		local asset = Asset()
		asset:unmarshal(assettbl)
		self:add(asset)
	end
end

return AssetManager
