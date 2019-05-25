--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Region class.
--]]

require("lfs")
local class      = require("libs.class")
local utils      = require("libs.utils")
local Template   = require("dct.template")
local Objective  = require("dct.objective")
local Logger     = require("dct.logger")
local DebugStats = require("dct.debugstats")

local tplkind = {
	["TEMPLATE"]  = 1,
	["EXCLUSION"] = 2,
}

--[[
--  Region class
--    base class that reads in a region definition.
--
--  Storage of region:
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
--]]
local Region = class()
function Region:__init(regionpath)
	local tpldirs = {
		["base"]     = "bases",
		["facility"] = "facilities",
		["mission"]  = "missions",
	}

	self.path = regionpath
	self.__templates  = {}
	self.__tpltypes   = {}
	self.__exclusions = {}
	self.logger   = Logger.getByName("region")
	self.logger:debug("=> regionpath: "..regionpath)
	self:__loadMetadata(regionpath.."/region.def")
	self.dbgstats = DebugStats.getDebugStats()
	self.dbgstats:registerStat(self.name.."-templates", 0,
		self.name.."-template(s) loaded")
	utils.foreach(self, pairs, self.__checkExists, tpldirs)
end

function Region:__loadMetadata(regiondefpath)
	local c = pcall(dofile, regiondefpath)
	assert(c, "failed to parse: region file, '" ..
			regiondefpath .. "' path likely doesn't exist")
	assert(region ~= nil, "no region structure defined")

	local r = region
	region = nil
	self:__checkRegion(r)
end

function Region:__checkRegion(r)
	if r["name"] == nil then
		assert(false, "region is missing a name")
	end
	utils.mergetables(self, r)
end

function Region:__checkExists(tpltype, dirname)
	local path = self.path .. "/" .. dirname
	local attr = lfs.attributes(path)
	if attr == nil or attr.mode ~= "directory" then
		self.logger:debug("=> checkExists: path doesn't exist; "..path)
		return
	end
	self:__getTemplates(tpltype, dirname, self.path)
end

function Region:__getTemplates(tpltype, dirname, basepath)
	local tplpath = basepath .. "/" .. dirname
	self.logger:debug("=> tplpath: "..tplpath)

	for filename in lfs.dir(tplpath) do
		if filename ~= "." and filename ~= ".." then
			local fpath = tplpath .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				self:__getTemplates(tpltype, filename, tplpath)
			else
				if string.find(fpath, ".stm") ~= nil then
					local dctString = string.gsub(fpath, ".stm", ".dct")
					self:__addTemplate(Template(fpath, dctString))
					self.dbgstats:incstat(self.name.."-templates", 1)
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

function Region:generate(theater)
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
			theater:addObjective(Template.side.RED, Objective(tpl))
			table.remove(names, idx)
			limits.current = 1 + limits.current
		end
	end
end

return Region
