--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for defining a region.
--]]

require("io")
require("lfs")
local class    = require("libs.class")
local utils    = require("libs.utils")
local template = require("dct.template")

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

local function getTemplates(tpltype, dirname, ctx)
	local tplpath = ctx.path .. "/" .. dirname

	for filename in lfs.dir(tplpath) do
		if filename ~= "." and filename ~= ".." then
			local fpath = tplpath .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local newctx = {}
				newctx.cls  = ctx.cls
				newctx.path = tplpath
				getTemplates(tpltype, filename, newctx)
			else
				if string.find(fpath, ".stm") ~= nil then
					local dctString = string.gsub(fpath, ".stm", ".dct")
					local t = template.Template(fpath, dctString)
					assert(addTemplate(ctx.cls, tpltype, t.name, t),
						"duplicate template '".. t.name .. "' defined; " ..
						fpath)
				end
			end
		end
	end
end

local function checkExists(tpltype, dirname, ctx)
	local p = io.open(ctx.path .. "/" .. dirname)
	if p == nil then
		return
	else
		io.close(p)
	end

	getTemplates(tpltype, dirname, ctx)
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
	local tpldirs = {
		["base"]     = "bases",
		["facility"] = "facilities",
		["mission"]  = "missions",
	}

	local ctx = {
		["cls"]  = self,
		["path"] = regionpath,
	}

	self:__readRegionDef(regionpath.."/region.def")
	utils.foreach(tpldirs, pairs, checkExists, ctx)
end

function Region:__readRegionDef(regiondefpath)
	local rc = false
	local msg = "none"

	rc = pcall(dofile, regiondefpath)
	assert(rc, "failed to parse: region file, '" ..
			regiondefpath .. "' path likely doesn't exist")
	assert(region ~= nil, "no region structure defined")

	local r = region
	region = nil

	rc, msg = validateRegionStruct(r)
	assert(rc, msg .. ", " .. regiondefpath)
	for key, data in pairs(r) do
		self[key] = data
	end
end

return {
	["Region"]      = Region,
}
