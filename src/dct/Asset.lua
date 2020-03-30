--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling Assets.
-- An Asset is a group of objects in the game world
-- that can be destroyed by the opposing side.
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.utils")
local settings = _G.dct.settings

local function generateCodename(objtype)
	local codenamedb = settings.codenamedb
	local typetbl = codenamedb[objtype]

	if typetbl == nil then
		typetbl = codenamedb.default
	end

	local idx = math.random(1, #typetbl)
	return typetbl[idx]
end

local function getcollection(assettype, asset, template, region)
	local collection = nil
	if assettype == dctenum.assetType.AIRBASE then
		collection = require("dct.dcscollections.NullCollection")
	elseif assettype == dctenum.assetType.AIRSPACE then
		collection = require("dct.dcscollections.AirspaceCollection")
	elseif dctenum.assetClass.STRATEGIC[assettype] then
		collection = require("dct.dcscollections.StaticCollection")
	else
		assert(false, "unsupported asset type: "..assettype)
	end
	return collection(asset, template, region)
end

--[[
Asset:
	attributes(private):
	- _collection<IObjectCollection>

	attributes(public, read-only):
	- type
	- briefing
	- owner
	- rgnname
	- tplname
	- name
	- codename

	methods(public):
	- getPriority(side)
		- get the priority of the asset
	- setPriority(side, tbl)
		- modify the priority of the asset

	Intel - an intel level of zero implies the given side has no
	idea about the asset
	- getIntel(side)
		- get the intel level the specified side has on this asset
	- setIntel(side, val)

	- isTargeted(side)
		- is the specified side currently targeting the asset?
	- setTargeted(side, val)
		- set the targeted state for a side for an asset
	- marshal()
		- marshal the asset for serialization
	- unmarshal(data)
		- unmarshal the asset from a seralized stream
	- IObjectCollection methods
--]]

local Asset = class()
function Asset:__init(template, region)
	self._marshalnames = {
		"_targeted", "_intel", "_priority", "type", "briefing",
		"owner", "rgnname", "tplname", "name", "codename",
	}

	self._targeted   = {}
	self._intel      = {}
	self._priority   = {}
	for _, side in pairs(coalition.side) do
		-- TODO: convert targeted to a number instead of a bool
		--   check so we can count how many times a given asset
		--   is targeted, used for CAP stations.
		self._targeted[side] = false
		self._intel[side]    = 0
		self._priority[side] = {
			["region"] = 0,
			["asset"]  = 0,
		}
	end
	self._initcomplete = false
	if template ~= nil and region ~= nil then
		self.type     = template.objtype
		self.briefing = template.desc
		self.owner    = template.coalition
		self.rgnname  = region.name
		self.tplname  = template.name
		self.name     = region.name.."_"..self.owner.."_"..template.name
		self.codename = generateCodename(self.type)
		self._intel[self.owner] = dctutils.INTELMAX
		if self.owner ~= coalition.side.NEUTRAL and template.intel then
			self._intel[dctutils.getenemy(self.owner)] = template.intel
		end
		for _, side in pairs(coalition.side) do
			self._priority[side] = {
				["region"] = region.priority,
				["asset"]  = template.priority,
			}
		end
		self._collection = getcollection(self.type, self, template, region)
		self._initcomplete = true
	end
end

-- TODO: not sure intel and priority should be stored with a given
--  Asset because each side may have a different view and ordering
--  for the Asset.
function Asset:getPriority(side)
	return ((self._priority[side].region * 65536) +
		self._priority[side].asset)
end

function Asset:setPriority(side, tbl)
	utils.mergetables(self._priority[side], tbl)
end

function Asset:getIntel(side)
	return self._intel[side]
end

function Asset:setIntel(side, val)
	assert(type(val) == "number", "value error: must be a number")
	self._intel[side] = val
end

function Asset:isTargeted(side)
	return self._targeted[side]
end

function Asset:setTargeted(side, val)
	assert(type(val) == "boolean",
		"value error: argument must be of type bool")
	self._targeted[side] = val
end

function Asset:getCollection()
	return self._collection
end

function Asset:getLocation()
	return self._collection:getLocation()
end

function Asset:getStatus()
	return self._collection:getStatus()
end

function Asset:isDead()
	return self._collection:isDead()
end

function Asset:setDead(val)
	return self._collection:setDead(val)
end

function Asset:checkDead()
	self._collection:checkDead()
end

function Asset:getObjectNames()
	return self._collection:getObjectNames()
end

function Asset:onDCSEvent(event)
	self._collection:onDCSEvent(event)
end

function Asset:isSpawned()
	return self._collection:isSpawned()
end

function Asset:spawn()
	self._collection:spawn()
end

function Asset:destroy()
	self._collection:destroy()
end

function Asset:marshal()
	assert(self._initcomplete == true, "runtime error: init not complete")
	local tbl = {}
	tbl.collection = self._collection:marshal()
	for _, attribute in pairs(self._marshalnames) do
		tbl[attribute] = self[attribute]
	end
	return tbl
end

function Asset:unmarshal(data)
	assert(self._initcomplete == false,
		"runtime error: init completed already")
	local collectiondata = data.collection
	data.collection = nil
	utils.mergetables(self, data)
	self._collection = getcollection(data.type, self)
	self._collection:unmarshal(collectiondata)
	self._initcomplete = true
end

return Asset

--[[
-- DynamicAsset
--   represents assets that can move
--  difference from BaseAsset
   * DCS-objects, has associated DCS objects
     * objects move
     * has death goals due to having DCS objects
   * associates a "team leader" AI with the asset to control the
     spawned DCS objects

-- PlayerAsset
--  inherents from DynamicAsset
--   flight groups with player slots in them
--  difference from BaseAsset and DynamicAsset
   * DCS-objects, has associated DCS objects
     * objects move
     * has death goals due to having DCS objects
     * spawn, nothing to spawn
   * invincible, asset cannot die (i.e. be deleted)
   * no associated "team leader" AI
   * player specific isSpawned() test - why?
   * enabled, asset can be enabled/disabled
     * DCS flag associated to control if the slot is enabled
       (think airbase captured so slot should not be joinable)
   * registers with an airbase asset

-- AirbaseAsset
-- is a composite asset consisting of multiple other assets
--   (squadrons, players, defense forces, etc)
--  inherents from BaseAsset, difference from:
   * depending on underlying DCS object type the deathgoal will either
     be the death of the underlying unit or the asset can never die it
     just triggers an internal event notifying the observers of the
     change in side
   * ability to register an associated asset; registration would
     consist of:
       - asset name and asset type (player, squadron, defense force,
         underlying asset)
   * on death the assets associated are marked as dead or disabled
   * provides custom functions to spawn an aircraft group

-- SquadronAsset
--  inherets from BaseAsset
   * being spawned means the asset is "active"
   * the deathgoal is when all aircraft in the squadron are destroyed
--]]
