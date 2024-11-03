--- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Region class.

require("lfs")
require("math")
require("libs")
local class      = libs.classnamed
local utils      = libs.utils
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local vector     = require("dct.libs.vector")
local Marshallable = require("dct.libs.Marshallable")
local Template   = require("dct.templates.Template")
local Logger     = dct.libs.Logger.getByName("Region")

local tplkind = {
	["TEMPLATE"]  = 1,
	["EXCLUSION"] = 2,
}

local DOMAIN = {
	["AIR"]  = "air",
	["LAND"] = "land",
	["SEA"]  = "sea",
}

local initasset = {
	--[[
	[dctenum.assetType.RESOURCE]    = true,
	[dctenum.assetType.AMMODUMP]    = true,
	[dctenum.assetType.FUELDUMP]    = true,
	[dctenum.assetType.C2]          = true,
	[dctenum.assetType.BUNKER]      = true,
	[dctenum.assetType.CHECKPOINT]  = true,
	[dctenum.assetType.MISSILE]     = true,
	[dctenum.assetType.OCA]         = true,
	[dctenum.assetType.ARMYBASE]    = true,
	[dctenum.assetType.AIRBASE]     = true,
	[dctenum.assetType.PORT]        = true,
	[dctenum.assetType.CV]          = true,
	[dctenum.assetType.HELOCARRIER] = true,
	[dctenum.assetType.FARP]        = true,
	[dctenum.assetType.GROUND]      = true,
	[dctenum.assetType.JTAC]        = true,
	[dctenum.assetType.EWR]         = true,
	[dctenum.assetType.SAM]         = true,
	[dctenum.assetType.SHORAD]      = true,
	[dctenum.assetType.SHIP]        = true,
	--]]
}

local function processlimits(_, tbl)
	-- process limits; convert the human readable asset type names into
	-- their numerical equivalents.
	local limits = {}
	for key, data in pairs(tbl.limits) do
		local typenum = dctenum.assetType[string.upper(key)]
		if typenum == nil then
			Logger:warn("invalid asset type '"..key..
				"' found in limits definition in file: "..
				tbl.regiondef or "nil")
		else
			limits[typenum] = data
		end
	end
	tbl.limits = limits
	return true
end

local function processlinks(keydata, tbl)
	local links = {}
	for k, v in pairs(tbl[keydata.name]) do
		local d = string.upper(k)
		if DOMAIN[d] ~= nil then
			links[DOMAIN[d]] = v
		end
	end
	tbl[keydata.name] = links
	return true
end

local function checklocation(keydata, tpl)
	local loc = tpl[keydata.name]

	for _, val in pairs({"x", "y"}) do
		if loc[val] == nil or type(loc[val]) ~= "number" then
			return false, "location defined in template is invalid"
		end
	end
	local vec2 = vector.Vector2D(loc)
	tpl[keydata.name] =
		vector.Vector3D(vec2, land.getHeight(vec2:raw())):raw()
	return true
end

local validationdata = {
	{
		["name"] = "name",
		["type"] = "string",
	}, {
		["name"] = "priority",
		["type"] = "number",
	}, {
		["name"] = "location",
		["type"] = "table",
		["default"] = {},
		["check"] = checklocation
	}, {
		["name"] = "limits",
		["type"] = "table",
		["default"] = {},
		["check"] = processlimits,
	}, {
		["name"] = "altitude_floor",
		["type"] = "number",
		["default"] = 914.4, -- meters; 3000ft msl
	}, {
		["name"] = "links",
		["type"] = "table",
		["check"] = processlinks,
		["default"] = {},
	}, {
		["name"] = "builtin",
		["type"] = "boolean",
		["default"] = false,
	},
}

local function validate(data)
	Logger:debug("=> regiondefpath: "..tostring(data.regiondef))
	utils.checkkeys(validationdata, data)
	return true
end

local function getTemplates(self, basepath)
	local ignorepaths = {
		["."] = true,
		[".."] = true,
		["region.def"] = true,
	}

	Logger:debug("=> basepath: "..basepath)
	for filename in lfs.dir(basepath) do
		if ignorepaths[filename] == nil then
			local fpath = basepath..utils.sep..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				getTemplates(self, basepath..utils.sep..filename)
			elseif string.find(fpath, ".dct", -4, true) ~= nil then
				Logger:debug("=> process template: "..fpath)
				local stmpath = string.gsub(fpath, "[.]dct", ".stm")
				if lfs.attributes(stmpath) == nil then
					stmpath = nil
				end
				self:addTemplate(
					Template.fromFile(fpath, stmpath))
			end
		end
	end
end

local function createExclusion(self, tpl)
	self._exclusions[tpl.exclusion] = {
		["ttype"] = tpl.objtype,
		["names"] = {},
	}
end

local function registerExclusion(self, tpl)
	assert(tpl.objtype == self._exclusions[tpl.exclusion].ttype,
	       "exclusions across objective types not allowed, '"..
	       tpl.name.."'")
	table.insert(self._exclusions[tpl.exclusion].names,
	             tpl.name)
end

local function registerType(self, kind, ttype, name)
	local entry = {
		["kind"] = kind,
		["name"] = name,
	}

	if self._tpltypes[ttype] == nil then
		self._tpltypes[ttype] = {}
	end
	table.insert(self._tpltypes[ttype], entry)
end

local function addAndSpawnAsset(self, name, assetmgr)
	if name == nil then
		return nil
	end

	local tpl = self:getTemplateByName(name)
	if tpl == nil then
		return nil
	end

	local asset = tpl:createObject()
	assetmgr:add(asset)
	tpl:generate(self, assetmgr, asset)
	return asset
end

local function associateBases(self)
	for name, tpl in pairs(self._templates) do
		if tpl.basedat ~= nil then
			local ptpl = self:getTemplateByName(tpl.basedat)

			if ptpl then
				ptpl.subordinates[name] = true
			end
		end
	end
end

--  Region class
--    base class that reads in a region definition.
--
--    properties
--    ----------
--      * name
--      * priority
--
--    Storage
--    -------
--		_templates   = {
--			["<tpl-name>"] = Template(),
--		},
--		_tpltypes    = {
--			<ttype> = {
--				[#] = {
--					kind = tpl | exclusion,
--					name = "<tpl-name>" | "<ex-name>",
--				},
--			},
--		},
--		_exclusions  = {
--			["<ex-name>"] = {
--				ttype = <ttype>,
--				names = {
--					[#] = ["<tpl-name>"],
--				},
--			},
--		}
--
--    region.def File
--    ---------------
--      Required Keys:
--        * priority - how high in the targets from this region will be
--				ordered
--        * name - the name of the region, mainly used for debugging
--
--      Optional Keys:
--        * limits - a table defining the minimum and maximum number of
--              assets to spawn from a given asset type
--              [<objtype>] = { ["min"] = <num>, ["max"] = <num>, }

-- TODO: allow campaign designers the ability to mark which regions are
-- "enabled" when a new theater is generated. Only enabled regions will
-- generate initial assets. As the campaign progresses regions can be
-- enabled dynamically.
-- TODO: allow campaign designers the ability to mark which regions are
-- "start" regions. That way player slots will only be spawned in those
-- regions.
local Region = class("Region", Marshallable)
function Region:__init(data)
	Marshallable.__init(self)

	self._valid = validate(data)
	if not self._valid then
		return
	end

	utils.mergetables(self, data)
	self._templates    = {}
	self._tpltypes     = {}
	self._exclusions   = {}
	self.centroid      = {}
	self.weight        = {}
	for _, side in pairs(coalition.side) do
		self.weight[side] = 0
	end
	self.owner         = dctutils.coalition.NEUTRAL
	self.radius        = 25
	self.DOMAIN        = nil
	self.fromFile      = nil

	self:_addMarshalNames({
		"location",
		"links",
		"radius",
	})

	Logger:debug("=> regionpath: "..tostring(self.path))
	if not self.builtin then
		getTemplates(self, self.path)
		associateBases(self)
	end
	Logger:debug("'"..self.name.."' Loaded")
end

Region.DOMAIN = DOMAIN

function Region.fromFile(path)
	local deffile = path..utils.sep.."region.def"
	local region = utils.readlua(deffile)

	if region.region then
		region = region.region
	end

	region.path = path
	region.regiondef = deffile
	return Region(region)
end

function Region:addTemplate(tpl)
	if not tpl:isValid() then
		-- we do not need to log anything as the Template class will
		-- have done this for us.
		return
	end

	if self._templates[tpl.name] ~= nil then
		Logger:error(string.format("duplicate template '%s' "..
			     "defined; %s", tpl.name, tostring(tpl.filedct)))
		return
	end

	if tpl.theater ~= env.mission.theatre then
		Logger:warn(string.format("Region(%s):Template(%s) not "..
			"for map(%s):template(%s) - ignoring",
			self.name, tpl.name, env.mission.theatre, tpl.theater))
		return
	end

	tpl:joinRegion(self)
	Logger:debug("  + add template: "..tpl.name)
	self._templates[tpl.name] = tpl
	if tpl.exclusion ~= nil then
		if self._exclusions[tpl.exclusion] == nil then
			createExclusion(self, tpl)
			registerType(self, tplkind.EXCLUSION,
				tpl.objtype, tpl.exclusion)
		end
		registerExclusion(self, tpl)
	else
		registerType(self, tplkind.TEMPLATE, tpl.objtype, tpl.name)
	end
end

function Region:getTemplateByName(name)
	if name == nil then
		return nil
	end
	return self._templates[name]
end

function Region:_generate(assetmgr, objtype, names)
	local limits = {
		["min"]     = #names,
		["max"]     = #names,
		["limit"]   = #names,
		["current"] = 0,
	}

	if self.limits and self.limits[objtype] then
		limits.min   = self.limits[objtype].min
		limits.max   = self.limits[objtype].max
		limits.limit = math.random(limits.min, limits.max)
	end

	for i, tpl in ipairs(names) do
		if tpl.kind ~= tplkind.EXCLUSION and
		   self._templates[tpl.name].spawnalways == true then
			addAndSpawnAsset(self, tpl.name, assetmgr)
			table.remove(names, i)
			limits.current = 1 + limits.current
		end
	end

	while #names >= 1 and limits.current < limits.limit do
		local idx  = math.random(1, #names)
		local name = names[idx].name
		if names[idx].kind == tplkind.EXCLUSION then
			local i = math.random(1, #self._exclusions[name].names)
			name = self._exclusions[name]["names"][i]
		end
		addAndSpawnAsset(self, name, assetmgr)
		table.remove(names, idx)
		limits.current = 1 + limits.current
	end
end

-- generates all "strategic" assets for a region from
-- a spawn format (limits). We then immediatly register
-- that asset with the asset manager (provided) and spawn
-- the asset into the game world. Region generation should
-- be limited to mission startup.
function Region:generate()
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local tpltypes = utils.deepcopy(self._tpltypes)

	for objtype, _ in pairs(initasset) do
		local names = tpltypes[objtype]
		if names ~= nil then
			self:_generate(assetmgr, objtype, names)
		end
	end
end

function Region:getWeight(side)
	return self.weight[side]
end

function Region:getPoint()
	return self.location
end

function Region:getEdges(domain)
	assert(utils.getkey(Region.DOMAIN, domain),
		"value error: invalid domain")
	return utils.deepcopy(self.links[domain])
end

local function get_asset_weight(asset)
	local weight = asset.cost
	if weight == 0 then
		weight = 1
	end
	Logger:debug("asset weight("..asset.name.."): "..tostring(weight))
	return weight
end

local function handleDead(region, event)
	local asset = event.initiator
	region.weight[asset.owner] = region.weight[asset.owner] -
		get_asset_weight(asset)
	if region.weight[asset.owner] < 0 then
		region.weight[asset.owner] = 0
	end
	Logger:debug("Region("..region.name..").handleDead - "..
		"new weight: "..tostring(region.weight[asset.owner]))
end

local function handleAddAsset(region, event)
	local asset = event.initiator
	region.weight[asset.owner] = region.weight[asset.owner] +
		get_asset_weight(asset)
	Logger:debug("Region("..region.name..").handleAddAsset - "..
		"new weight: "..tostring(region.weight[asset.owner]))
end

local handlers = {
	[dctenum.event.DCT_EVENT_DEAD] = handleDead,
	[dctenum.event.DCT_EVENT_ADD_ASSET] = handleAddAsset,
}

function Region:onDCTEvent(event)
	local side = coalition.side
	local handler = handlers[event.id]

	if handler == nil or
	   dctenum.assetClass.STRATEGIC[event.initiator.type] == nil then
		return
	end

	handler(self, event)

	if self.weight[side.RED] == 0 or self.weight[side.BLUE] == 0 then
		if self.weight[side.RED] - self.weight[side.BLUE] == 0 then
			self.owner = dctutils.coalition.NEUTRAL
		else
			if self.weight[side.RED] > self.weight[side.BLUE] then
				self.owner = dctutils.coalition.RED
			else
				self.owner = dctutils.coalition.BLUE
			end
		end
		return
	end

	local c = 2
	local ratioB = self.weight[side.BLUE] / self.weight[side.RED]

	if ratioB > c then
		self.owner = dctutils.coalition.BLUE
	elseif ratioB < 1/c then
		self.owner = dctutils.coalition.RED
	else
		self.owner = dctutils.coalition.CONTESTED
	end
end

return Region
