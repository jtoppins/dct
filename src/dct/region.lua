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

local function addTemplate(tbl, lvl1, lvl2, val)
	if tbl[lvl1] then
			if tbl[lvl1][lvl2] ~= nil then
				return false
			end
			tbl[lvl1][lvl2] = val
	else
		tbl[lvl1] = {}
		tbl[lvl1][lvl2] = val
	end

	return true
end

local function getTemplates(cls, tpltype, dirname, basepath)
	local tplpath = basepath .. "/" .. dirname
	cls.logger:debug("=> tplpath: "..tplpath)

	for filename in lfs.dir(tplpath) do
		if filename ~= "." and filename ~= ".." then
			local fpath = tplpath .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				getTemplates(cls, tpltype, filename, tplpath)
			else
				if string.find(fpath, ".stm") ~= nil then
					local dctString = string.gsub(fpath, ".stm", ".dct")
					local t = Template(fpath, dctString)
					assert(addTemplate(cls, tpltype, t.name, t),
						"duplicate template '".. t.name .. "' defined; " ..
						fpath)
					cls.dbgstats:incstat(cls.name.."-templates", 1)
				end
			end
		end
	end
end

local function checkExists(cls, tpltype, dirname)
	local path = cls.path .. "/" .. dirname
	local attr = lfs.attributes(path)
	if attr == nil or attr.mode ~= "directory" then
		cls.logger:debug("=> checkExists: path doesn't exist; "..path)
		return
	end
	getTemplates(cls, tpltype, dirname, cls.path)
end

local function validateRegionStruct(r)
	if r["name"] == nil then
		return false, "region is missing a name"
	end
	return true, "no error"
end


--[[
--  Region class
--    base class that reads in a region definition.
--
--  Storage of region:
--		base     = {
--			<tplname> = Template(),
--		},
--		facility = {
--			<tplname> = Template(),
--		},
--		mission  = {
--			<tplname> = Template(),
--		}
--]]
local Region = class()
function Region:__init(regionpath)
	self.path = regionpath

	local tpldirs = {
		["base"]     = "bases",
		["facility"] = "facilities",
		["mission"]  = "missions",
	}

	self.logger   = Logger.getByName("region")
	self.logger:debug("=> regionpath: "..regionpath)
	self:__loadMetadata(regionpath.."/region.def")
	self.dbgstats = DebugStats.getDebugStats()
	self.dbgstats:registerStat(self.name.."-templates", 0,
		self.name.."-template(s) loaded")
	utils.foreach(self, pairs, checkExists, tpldirs)
end

function Region:__loadMetadata(regiondefpath)
	local c = pcall(dofile, regiondefpath)
	assert(c, "failed to parse: region file, '" ..
			regiondefpath .. "' path likely doesn't exist")
	assert(region ~= nil, "no region structure defined")

	local r = region
	region = nil

	local rc, msg = validateRegionStruct(r)
	assert(rc, msg .. "; " .. regiondefpath)
	for key, data in pairs(r) do
		self[key] = data
	end
end

function Region:generate()
	local objs = {}

	-- TODO: generate base objectives

	if self.facility then
		-- build lookup table to be used to randomly select
		-- templates
		--
		-- tplnames = {
		--     <type> = {
		--         [#] = "<name>"
		--     },
		-- }
		local tplnames = {}
		for name, tpl in pairs(self.facility) do
			if tplnames[tpl.objtype] == nil then
				tplnames[tpl.objtype] = {}
			end
			table.insert(tplnames[tpl.objtype], name)
		end

		-- generate facility objectives
		for objtype, limits in pairs(self.limits) do
			limits.limit = math.random(limits.min, limits.max)
			limits.current = 0

			while limits.limit > 0 and tplnames[objtype] ~= nil and
					#tplnames[objtype] >= 1 do
				local idx = math.random(1, #tplnames[objtype])
				local tpl = self.facility[tplnames[objtype][idx]]
				local obj = Objective(tpl)
				table.insert(objs, obj)
				table.remove(tplnames[objtype], idx)
				limits.current = 1 + limits.current
				if limits.current == limits.limit then
					break
				end
			end
		end
	end

	return objs
end

return Region
