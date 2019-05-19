--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

local class    = require("libs.class")
local utils    = require("libs.utils")

local coa_side = {
	["RED"]  = "red",
	["BLUE"] = "blue",
}

local categorymap = {
	["HELICOPTER"] = 'HELICOPTER',
	["SHIP"]       = 'SHIP',
	["VEHICLE"]    = 'GROUND_UNIT',
	["PLANE"]      = 'AIRPLANE',
	["STATIC"]     = 'STRUCTURE',
}

local function lookupname(name, namelist)
	namelist = namelist or {}
	if namelist[name] ~= nil then
		name = namelist[name]
	end
	return name
end

local function checktype(val)
	local allowed = {
		-- strategic types
		"ammodump",
		"bunker",
		"c2",
		"checkpoint",
		"depot",
		"ewr",
		"factory",
		"fueldump",
		"missile",
		"oca",
		"port",
		"sam",
		"warehouse",

		-- bases
		"airbase",
		"farp",

		-- tactical
		"armor",
		"supply",
		"sea",

		-- control zones
		"keepout",
	}

	for _, v in ipairs(allowed) do
		if v == val then
			return true
		end
	end
end

local function overrideGroupOptions(grp, ctx)
	local opts = {
		visible        = true,
		uncontrollable = true,
		uncontrolled   = true,
		hidden         = false,
		lateActivation = false,
	}

	for k, v in pairs(opts) do
		if grp[k] ~= nil then grp[k] = v end
	end
	grp.name    = lookupname(grp.name, ctx.names)
	grp.groupId = nil

end

local function overrideUnitOptions(ctx, key, unit)
	if unit.playerCanDriver ~= nil then
		unit.playerCanDrive = false
	end
	unit.unitId = nil
	unit.name = lookupname(unit.name, ctx.names)
end

local function overrideName(ctx, key, obj)
	obj.name = lookupname(obj.name, ctx.names)
end

local function spawnGroup(category, id, group)
	assert(id)
	assert(group)
	assert(category)
	coalition.addGroup(group.countryid,
			   Unit.Category[categorymap[string.upper(category)]],
			   group.data)
end

local function spawnStatic(unused, id, static)
	assert(id)
	assert(static)
	coalition.addStaticObject(static.countryid, static.data)
end

local function spawn(coa_data)
	for cat_idx, cat_data in pairs(coa_data) do
		if cat_idx == 'static' then
			utils.foreach(cat_idx,
				ipairs,
				spawnStatic,
				cat_data)
		else
			utils.foreach(cat_idx,
				ipairs,
				spawnGroup,
				cat_data)
		end
	end
end


--[[
--  Template class
--    base class that reads in a template file and organizes
--    the data for spawning.
--
--  Storage of templates:
--  side = {
--      category = {
--          # = {
--              countryid = id,
--              grpdata   = data
--          }
--      }
--  }
--]]
local Template = class()
function Template:__init(stmfile, dctfile)
	self.path = stmfile

	local rc = pcall(dofile, stmfile)
	assert(rc, "failed to parse: stmfile, of type "..type(stmfile))
	assert(staticTemplate ~= nil)

	local tpl = staticTemplate
	staticTemplate = nil

	self.name    = lookupname(tpl.name, tpl.localization.DEFAULT)
	self.theatre = tpl.theatre
	self.desc    = tpl.desc
	self.tpldata = {}

	for coa_key, coa_data in pairs(tpl.coalition) do
		self:__processCoalition(coa_key, coa_data,
					tpl.localization.DEFAULT)
	end

	self:__loadMetadata(dctfile)
end

function Template:__loadMetadata(dctfile)
	local requiredkeys = {
		["objtype"]  = {
			-- kind of objective; ammodump, factory, etc
			["type"]  = "string",
			["check"] = checktype,
		},
	}

	local rc = pcall(dofile, dctfile)
	assert(rc, "failed to parse: dctfile, of type "..type(dctfile))
	assert(metadata ~= nil)

	-- validate metadata
	for key, data in pairs(requiredkeys) do
		if metadata[key] == nil or
		   type(metadata[key]) ~= data["type"] or
		   not data["check"](metadata[key]) then
			assert(false, "invalid or missing option '"..key..
			       "' in dct file; "..dctfile)
		end
	end
	utils.mergetables(self, metadata)
	metadata = nil
end

function Template:__processCoalition(side, coa, names)
	if side ~= 'red' and side ~= 'blue' and
	   type(coa) ~= 'table' then
		return
	end

	if coa.country == nil or type(coa.country) ~= 'table' then
		return
	end

	for _, ctry_data in ipairs(coa.country) do
		self:__processCountry(side, ctry_data, names)
	end
end

function Template:__processCountry(side, ctry, names)
	local funcmap = {
		["HELICOPTER"] = self.__addOneGroup,
		["SHIP"]       = self.__addOneGroup,
		["VEHICLE"]    = self.__addOneGroup,
		["PLANE"]      = self.__addOneGroup,
		["STATIC"]     = self.__addOneStatic,
	}

	local ctx = {}
	ctx.side      = side
	ctx.category  = "none"
	ctx.countryid = ctry.id
	ctx.names     = names

	for cat, data in pairs(categorymap) do
		cat = string.lower(cat)
		if ctry[cat] and type(ctry[cat]) == 'table' and
		   ctry[cat].group then
			ctx.category = cat
			utils.foreach(self,
					ipairs,
					funcmap[string.upper(cat)],
					ctry[cat].group,
					ctx)
		end
	end
end

function Template:__addOneStatic(idx, grp, ctx)
	local tbl = {}

	self:__createTable(ctx)

	tbl.data        = grp.units[1]
	tbl.data.dead   = grp.dead
	tbl.data.name   = self.name .. " " .. ctx.side .. " static " ..
			  #self.tpldata[ctx.side][ctx.category]
	-- delete unneeded fields
	tbl.data.unitId = nil
	tbl.countryid = ctx.countryid

	-- TODO: setup metadata like parsing group/unit names
	-- to determine how much of the group needs to be
	-- destroyed or if specific units need to be
	-- damaged/destroyed.
	-- 	Notes:
	-- 	if deadstate is a number, it represents
	-- 	the overall group's health state as defined
	-- 	by the arithmetic mean
	--
	-- 	if deadstate is a table, it represents
	-- 	a map keyed on unit position in the group
	-- 	and the unit's state. The absence of a unit's
	-- 	position key means it doesn't matter what that
	-- 	unit's state is.
	-- tbl.deadstate =

	table.insert(self.tpldata[ctx.side][ctx.category], tbl)
end

function Template:__addOneGroup(idx, grp, ctx)
	local tbl = {}

	self:__createTable(ctx)

	tbl.data = grp
	overrideGroupOptions(tbl.data, ctx)
	utils.foreach(ctx,
		      ipairs,
		      overrideUnitOptions,
			  tbl.data.units)
	utils.foreach(ctx,
		      ipairs,
		      overrideName,
			  tbl.data.route.points)
	tbl.countryid = ctx.countryid
	-- TODO: setup metadata like parsing group/unit names

	-- now override group/unit names to be unique to the
	-- template
	tbl.data.name = self.name .. " " .. ctx.side .. " " ..
			ctx.category .. " " .. #self.tpldata[ctx.side][ctx.category]
	utils.foreach(tbl.data.name,
		ipairs,
		function(base, i, obj)
			obj.name = base .. "-" .. i
		end,
		tbl.data.units)
	table.insert(self.tpldata[ctx.side][ctx.category], tbl)
end

function Template:__createTable(ctx)
	local data = self.tpldata
	if data[ctx.side] then
		if data[ctx.side][ctx.category] == nil then
			data[ctx.side][ctx.category] = {}
		end
	else
		data[ctx.side] = {}
		data[ctx.side][ctx.category] = {}
	end
end

-- PUBLIC INTERFACE
--
-- TODO: create additional spawn methods
-- member option: uniquenames - if true will override the
--		per-group and unit names making sure they are unique
--		within the mission

function Template:spawnSide(side)
	spawn(self.tpldata[side])
end

function Template:spawn()
	for _, coa_data in pairs(self.tpldata) do
		spawn(coa_data)
	end
end

Template.side = coa_side

return Template
