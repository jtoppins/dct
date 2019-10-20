--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local class   = require("libs.class")
local utils   = require("libs.utils")
local enum    = require("dct.enum")
local Logger  = require("dct.Logger").getByName("AssetManager")
local Command = require("dct.Command")

--[[
-- Discussion:
--  * do we check all assets marked to be checked or do we just
--    queue up individual commands for each asset to be checked?
--		If we hide the need for the check to be run inside the
--		Asset class we can just check all Asset objects w/o the
--		need to keep track in the AssetManager which assets need
--		checking. [choose this for now]
--  * what do we do with dead assets?
--    1. asset needs to be moved to the dead list
--    2. if asset is not to be preserved (a static to be shown as dead)
--       should we not just delete it?
--    3. if assets can just be deleted how do we know what should and
--       should not be removed from the 'saved state'? This would
--       imply that we just marshal all assets all the time.
--    For now if the asset is not of the 'strategic' type once it is
--    dead we will delete it. This means we need to delete the asset from
--      * assetset
--      * sideassets
--      * remove the asset entry from the marshal cache
--]]

local AssetCheckCmd = class(Command)

function AssetCheckCmd:__init(assetmgr)
	self._assetmgr = assetmgr
end

function AssetCheckCmd:execute(time)
	self._assetmgr:checkAssets(time)
end

local ASSET_CHECK_DELAY = 30

local AssetManager = class()

-- TODO: need to figure out the full life-cycle of an Asset and how it
-- would flow through this manager and what the interaction with other
-- systems looks like. Also, think about 'intel' and how that would fit
-- in, this might mean that the 'targetqueues' below are instead contained
-- in the per side AI commander. This would make sense because then the
-- asset manager could just be responsible for maintaining global knowledge
-- about all assets.

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
	-- 'true'. To get the actual asset object we need to lookup the
	-- name in a master asset list.
	self._sideassets = {
		[coalition.side.NEUTRAL] = {
			["alive"] = {},
			["dead"]  = {},
		},
		[coalition.side.RED]     = {
			["alive"] = {},
			["dead"]  = {},
		},
		[coalition.side.BLUE]    = {
			["alive"] = {},
			["dead"]  = {},
		},
	}

	-- keeps track of static/unit/group names to asset objects,
	-- remember all spawned Asset classes will need to register the names
	-- of their DCS objects with 'something', this will be the something.
	self._object2asset = {}

--[[
	-- local cache of all assets in a marshallable form
	self._marshaledassets = {}

	-- not sure if this complexity is needed
	self._dirtyassets = {}
--]]
end

function AssetManager:addAsset(asset)
	assert(asset ~= nil, "value error, asset object must be provided")

	--  * add asset to master list
	assert(self._assetset[asset.name] == nil, "asset name ('"..asset.name..
		"') already exists")
	self._assetset[asset.name] = asset

	--  * add asset to approperate side lists
	if asset:isDead() then
		self._sideassets[asset.owner].dead[asset.name] = true
	else
		self._sideassets[asset.owner].alive[asset.name] = true
		--  * read Asset's object names and setup object to asset mapping
		--     to be used in handling DCS events and other uses
		for _, objname in pairs(asset:getObjectNames()) do
			self._object2asset[objname] = asset.name
		end
	end

	--  * add asset to approperate commander's target list (later to be
	--     replaced by each side's detction capabilities)
	--     How do we add assets to a commander's target list? Since this
	--     manager has no knowledge of AI commanders.
	--  TODO: I don't need this just provide a function to return all asset
	--    names per side and a query interface to get the actual asset.

	--  * register the AssetManager as an observer with the Asset
	--	  events are; SPAWN, DEAD (entire Asset is dead),
	--	  DIRTY (something about the Asset has changed)
	-- [Do not need this at this time]
	-- asset:addObserver(self)

	--	* [do we need this?] notify observers that a new asset was added
	-- self:notify()
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
		return
	end
	self._theater:queueCommand(timer.getTime() + ASSET_CHECK_DELAY,
	                           AssetCheckCmd(self))
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
	self._lastchecked = timer.getTime()

	for _, asset in pairs(self._assetset) do
		asset:checkDead(force)
		if asset:isDead() then
			-- TODO: this should probably be a remove asset call
			local isstrat = enum.assetClass.STRATEGIC[asset["type"]] or false
			if isstrat then
				self._sideassets[asset.owner].alive[asset.name] = nil
				self._sideassets[asset.owner].dead[asset.name]  = true
			else
				self._sideassets[asset.owner].alive[asset.name] = nil
				self._sideassets[asset.owner].dead[asset.name]  = nil
				self._assetset[asset.name] = nil
				-- self._marshaledassets[asset.name] = nil
			end
			for _, objname in pairs(asset:getObjectNames()) do
				self._object2asset[objname] = nil
			end
		end
	end
	self._checkqueued = false
	Logger:debug("checkAssets() - runtime: "..timer.getTime()-perftime_s..
		" seconds, forced: "..force..", assets checked: ?? not written")
end

--[[
function AssetManager:markDirtyAsset(asset)
	self._dirtyassets[asset.name] = true
end
--]]

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
--[[
	if asset:isDirty() then
		self:markDirtyAsset(asset)
	end
--]]
end

function AssetManager:marshal(ignoredirty)
	-- TODO: marshal assets into a table and return to the caller
	
end

function AssetManager:unmarshal(data)
	-- TODO: read in and create all assets that were saved off
end

return AssetManager

-- TODO: Idea, a "TRANSPORT" asset could represent a helo transport mission
-- such as delivering special forces to a location where they then act as
-- a JTAC.
