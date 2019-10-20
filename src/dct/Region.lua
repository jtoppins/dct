--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Region class.
--]]

require("lfs")
local class      = require("libs.class")
local utils      = require("libs.utils")
local Template   = require("dct.Template")
local Asset      = require("dct.Asset")
local Logger     = require("dct.Logger").getByName("Region")
local DebugStats = require("dct.DebugStats").getDebugStats()
local dctenums   = require("dct.enum")

local tplkind = {
	["TEMPLATE"]  = 1,
	["EXCLUSION"] = 2,
}

--[[
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
--		__templates   = {
--			["<tpl-name>"] = Template(),
--		},
--		__tpltypes    = {
--			<ttype> = {
--				[#] = {
--					kind = tpl | exclusion,
--					name = "<tpl-name>" | "<ex-name>",
--				},
--			},
--		},
--		__exclusions  = {
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
--]]
local Region = class()
function Region:__init(regionpath)
	self.path = regionpath
	self.__templates  = {}
	self.__tpltypes   = {}
	self.__exclusions = {}
	Logger:debug("=> regionpath: "..regionpath)
	self:__loadMetadata(regionpath..utils.sep.."region.def")
	DebugStats:registerStat(self.name.."-templates", 0,
		self.name.."-template(s) loaded")
	self:__loadTemplates()
end

function Region:__loadMetadata(regiondefpath)
	Logger:debug("=> regiondefpath: "..regiondefpath)
	-- TODO: this construct on validating table keys is repeated
	-- a few times in the codebase, look at centeralizing this
	-- in a cleanup later.
	local requiredkeys = {
		["name"] = {
			["type"] = "string",
		},
		["priority"] = {
			["type"] = "number",
		},
	}

	assert(lfs.attributes(regiondefpath) ~= nil,
		"file does not exist: "..regiondefpath)

	local rc = pcall(dofile, regiondefpath)
	assert(rc, "failed to parse: "..regiondefpath)
	assert(region ~= nil, "no region structure defined in: "..regiondefpath)

	for key, data in pairs(requiredkeys) do
		if region[key] == nil or
		   type(region[key]) ~= data["type"] then
			assert(false, "invalid or missing option '"..key..
			       "' in region file; "..regiondefpath)
		end
	end

	-- process limits; convert the human readable asset type names into
	-- their numerical equivalents.
	local limits = {}
	for key, data in pairs(region.limits or {}) do
		local typenum = dctenums.assetType[string.upper(key)]
		if typenum == nil then
			Logger:warn("invalid asset type '"..key..
				"' found in limits definition in file: "..regiondefpath)
		else
			limits[typenum] = data
		end
	end
	region.limits = limits

	utils.mergetables(self, region)
	region = nil
end


function Region:__loadTemplates()
	for filename in lfs.dir(self.path) do
		if filename ~= "." and filename ~= ".." then
			local fpath = self.path.."/"..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				self:__getTemplates(filename, self.path)
			end
		end
	end
end

function Region:__getTemplates(dirname, basepath)
	local tplpath = basepath .. "/" .. dirname
	Logger:debug("=> tplpath: "..tplpath)

	for filename in lfs.dir(tplpath) do
		if filename ~= "." and filename ~= ".." then
			local fpath = tplpath .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				self:__getTemplates(filename, tplpath)
			else
				if string.find(fpath, ".stm") ~= nil then
					Logger:debug("=> process template: "..fpath)
					local dctString = string.gsub(fpath, ".stm", ".dct")
					self:__addTemplate(Template(self.name, fpath, dctString))
					DebugStats:incstat(self.name.."-templates", 1)
				end
			end
		end
	end
end

function Region:__addTemplate(tpl)
	assert(self.__templates[tpl.name] == nil,
			"duplicate template '"..tpl.name.."' defined; "..tpl.path)
	self.__templates[tpl.name] = tpl
	if tpl.exclusion ~= nil then
		if self.__exclusions[tpl.exclusion] == nil then
			self:__createExclusion(tpl)
			self:__registerType(tplkind.EXCLUSION, tpl.objtype, tpl.exclusion)
		end
		self:__registerExclusion(tpl)
	else
		self:__registerType(tplkind.TEMPLATE, tpl.objtype, tpl.name)
	end
end

function Region:__createExclusion(tpl)
	self.__exclusions[tpl.exclusion] = {
		["ttype"] = tpl.objtype,
		["names"] = {},
	}
end

function Region:__registerExclusion(tpl)
	assert(tpl.objtype == self.__exclusions[tpl.exclusion].ttype,
	       "exclusions across objective types not allowed, '"..
	       tpl.name.."'")
	table.insert(self.__exclusions[tpl.exclusion].names,
	             tpl.name)
end

function Region:__registerType(kind, ttype, name)
	local entry = {
		["kind"] = kind,
		["name"] = name,
	}

	if self.__tpltypes[ttype] == nil then
		self.__tpltypes[ttype] = {}
	end
	table.insert(self.__tpltypes[ttype], entry)
end

-- generates all "strategic" assets for a region from
-- a spawn format (limits). We then immediatly register
-- that asset with the asset manager (provided) and spawn
-- the asset into the game world. Region generation should
-- be limited to mission startup.
function Region:generate(assetmgr)
	local tpltypes = utils.deepcopy(self.__tpltypes)

	for objtype, names in pairs(tpltypes) do
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

		while #names >= 1 and limits.current < limits.limit do
			-- this could be optimized a little in that if we have no
			-- specific limits and want all the templates spawned
			-- we could skip getting the random number, not really worth it

			local idx  = math.random(1, #names)
			local name = names[idx].name
			if names[idx].kind == tplkind.EXCLUSION then
				local i = math.random(1, #self.__exclusions[name].names)
				name = self.__exclusions[name]["names"][i]
			end
			local tpl = self.__templates[name]
			local asset = Asset(tpl, self)
			assetmgr:addAsset(asset)
			asset:spawn()
			table.remove(names, idx)
			limits.current = 1 + limits.current
		end
	end
end

return Region
