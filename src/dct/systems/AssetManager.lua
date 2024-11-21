-- SPDX-License-Identifier: LGPL-3.0

--- Provides functions to define and manage Assets.
-- @classmod dct.systems.AssetManager
-- @alias AssetManager

require("libs")
local checklib = libs.check
local dctutils = require("dct.libs.utils")
local Command  = require("dct.libs.Command")
local System   = require("dct.libs.System")
local Observable = require("dct.libs.Observable")
local Marshallable = require("dct.libs.Marshallable")
--local Agent = require("dct.assets.Agent")

--- Iterate over groups and only visit non-player groups.
local function iterate_nonplayers(grps)
	local function fnext(state, index)
		local idx = index
		local grp
		repeat
			idx, grp = next(state, idx)
			if grp == nil then
				return nil
			end
		until(not dct.libs.utils.isplayergroup(grp))
		return idx, grp
	end
	return fnext, grps, nil
end

--- Enumerate non-player units found in the currently loaded
-- mission (miz) file.
-- @return list of non-player units found in the mission indexed
--     by unit name.
local function get_miz_units(logger)
	local units = {}
	local miz = dct.templates.MIZ(env)

	for _, grp in iterate_nonplayers(miz.groups) do
		for _, unit in ipairs(grp.data.units or {}) do
			local u = {}
			u.name = unit.name
			u.category = grp.category
			u.dead = false

			if units[u.name] ~= nil then
				logger:error("multiple same named miz placed"..
					     " objects exist: "..u.name)
			end
			units[u.name] = u
		end
	end
	return units
end

--- Central store for assets managed in DCT.
local AssetManager = libs.classnamed("AssetManager", System, Observable,
				     Marshallable)
AssetManager.enabled = true

--- Constructor.
function AssetManager:__init(theater)
	System.__init(self, theater,
		      System.SYSTEMORDER.ASSETMGR,
		      System.SYSTEMALIAS.ASSETMGR)
	Observable.__init(self)
	Marshallable.__init(self)
	self:_addMarshalNames({
		"_mizobjs",
	})

	self.updaterate = 2

	-- The master list of assets, regardless of side, indexed by name.
	-- Means Asset names must be globally unique.
	self._assetset = {}

	-- keeps track of static/unit/group names to asset objects,
	-- remember all spawned Asset classes will need to register the names
	-- of their DCS objects with 'something', this will be the something.
	self._object2asset = {}
	self._mizobjs = get_miz_units(self._logger)
	self._spawnq = {}
end

function AssetManager:initialize()
	self._theater:addObserver(self.onDCSEvent, self,
				  self.__clsname..".onDCSEvent")
end

function AssetManager:start()
	local cmd = Command(self.updaterate, self.__clsname..".update",
			    self.update, self)
	cmd:setRequeue(true)
	self._theater:queueCommand(cmd)

	for assetname, _ in pairs(self._spawnq) do
		self:getAsset(assetname):spawn(true)
	end
	self._spawnq = {}

	for _, unit in pairs(self._mizobjs) do
		if unit.dead then
			local func = Unit.getByName
			if unit.category == Unit.Category.STRUCTURE then
				func = StaticObject.getByName
			end
			local U = func(unit.name)
			if U then
				U:destroy()
			end
		end
	end
end

function AssetManager:remove(asset)
	if asset == nil then
		return
	end

	self._logger:debug("Removing asset: "..asset.name)

	asset:removeObserver(self)
	self._assetset[asset.name] = nil

	-- remove asset object names from name list
	for _, objname in pairs(asset:getObjectNames()) do
		self._object2asset[objname] = nil
	end

	asset:destroy()
end

function AssetManager:add(asset)
	assert(asset ~= nil, "value error: asset object must be provided")
	assert(self._assetset[asset.name] == nil, "asset name ('"..
		asset.name.."') already exists")

	if asset:isDead() then
		self._logger:debug("AssetManager:add - not adding dead asset: %s", asset.name)
		return
	end

	self._logger:debug("Adding asset: "..asset.name)

	self._assetset[asset.name] = asset
	asset:addObserver(self.onDCSEvent, self, "AssetManager.onDCSEvent")

	self._logger:debug("Adding object names for '%s'", asset.name)
	-- read Asset's object names and setup object to asset mapping
	-- to be used in handling DCS events and other uses
	for _, objname in pairs(asset:getObjectNames()) do
		self._logger:debug("    + %s", objname)
		self._object2asset[objname] = asset.name
	end

	self:notify(dct.event.build.addasset(asset))
end

function AssetManager:getAsset(name)
	return self._assetset[name]
end

function AssetManager:iterate()
	return next, self._assetset, nil
end

-- dcsObjName must be one of; group, static, or airbase names
function AssetManager:getAssetByDCSObject(dcsObjName)
	local assetname = self._object2asset[dcsObjName]
	if assetname == nil then
		return nil
	end
	return self._assetset[assetname]
end

--- return all assets matching filter function
--
-- @param filter Return a truthy value for assets that should be
--  returned by this function
-- @return a list of matched assets, even if empty
function AssetManager:filterAssets(filter)
	checklib.func(filter)

	local list = {}
	for name, asset in self:iterate() do
		if filter(asset) then
			list[name] = asset
		end
	end

	return list
end

function AssetManager:update()
	local deletionq = {}
	for _, asset in self:iterate() do
		if type(asset.update) == "function" then
			local ok, err = pcall(asset.update, asset)

			if not ok then
				dct.libs.utils.errhandler(err, asset._logger)
			end
		end
		if asset:isDead() then
			deletionq[asset.name] = true
		end
	end
	for name, _ in pairs(deletionq) do
		self:remove(self:getAsset(name))
	end
	return self.updaterate
end

local function handleDead(self, event)
	local objname = event.initiator:getName()
	self._object2asset[tostring(objname)] = nil

	if self._mizobjs[objname] ~= nil then
		self._mizobjs[objname].dead = true
	end
end

local function handleAssetDeath(self, event)
	local asset = event.initiator
	dct.Theater.singleton():getTickets():loss(asset.owner,
		asset:getDescKey("cost"), false)
	self:notify(event)
end

local handlers = {
	[world.event.S_EVENT_DEAD] = handleDead,
	[dct.event.ID.DCT_EVENT_DEAD] = handleAssetDeath,
}

function AssetManager:doOneObject(obj, event)
	if event.id > world.event.S_EVENT_MAX then
		return
	end

	local name = tostring(obj:getName())
	if obj.className_ ~= "Airbase" and
	   obj:getCategory() == Object.Category.UNIT and
	   obj:getGroup() ~= nil then
		name = obj:getGroup():getName()
	end

	local asset = self:getAssetByDCSObject(name)
	if asset == nil then
		self._logger:debug("onDCSEvent - asset doesn't exist, name: %s", name)
		self._object2asset[name] = nil
		return
	end
	asset:onDCTEvent(event)
end

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
		[dct.event.ID.DCT_EVENT_DEAD]         = true,
		--[world.event.S_EVENT_UNIT_LOST]     = true,
	}
	local objmap = {
		[world.event.S_EVENT_HIT]  = "target", -- type: Object
		[world.event.S_EVENT_KILL] = "target", -- type: Unit
		[world.event.S_EVENT_LAND] = "place", -- type: Object
		[world.event.S_EVENT_TAKEOFF] = "place", -- type: Object
	}

	if not relevents[event.id] then
		return
	end

	local objs = { event.initiator }
	if objmap[event.id] ~= nil then
		if event[objmap[event.id]] ~= nil then
			table.insert(objs, event[objmap[event.id]])
		end
	end

	for _, obj in ipairs(objs) do
		self:doOneObject(obj, event)
	end
	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

function AssetManager:marshal()
	local tbl = Marshallable.marshal(self) or {}
	tbl.assets = {}

	for name, asset in self:iterate() do
		if type(asset.marshal) == "function" and not asset:isDead() then
			tbl.assets[name] = asset:marshal()
		end
	end
	return tbl
end

function AssetManager:unmarshal(data)
	for _, assettbl in pairs(data.assets) do
		local asset = Agent()
		asset:unmarshal(assettbl)
		self:add(asset)
		if asset:isSpawned() then
			self._spawnq[asset.name] = true
		end
	end

	for _, unit in pairs(data._mizobjs) do
		local u = self._mizobjs[unit.name]
		if u ~= nil then
			u.dead = unit.dead
		end
	end
end

--[[
--  * Asset Impact Notifier:
--   (part of the default AssetManager)
--    - directly notify assets "near" the blast with line of sight
--      to the impact area as calculated 100m above the impact point

-- If there is a DCT asset of the same name as the DCS base,
-- notify the DCT asset it has been hit.
local function handlebase(base, data)
	local asset = data.theater:getAssetMgr():getAsset(base:getName())

	if asset == nil then
		return
	end

	asset:onDCTEvent(data.event)
end

	local vol = {
		id = world.VolumeType.SPHERE,
		params = {
			point = event.point,
			radius = 6000, -- allows for > 15000ft runway
		},
	}
	world.searchObjects(Object.Category.BASE, vol, handlebase,
		{
			["event"]   = event,
			["theater"] = self._theater,
		})

--]]

return AssetManager
