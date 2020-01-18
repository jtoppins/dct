--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles transforming an STM structure to a structure the Template
-- class knows how to deal with.
--]]

local utils = require("libs.utils")

local categorymap = {
	["HELICOPTER"] = 'HELICOPTER',
	["SHIP"]       = 'SHIP',
	["VEHICLE"]    = 'GROUND_UNIT',
	["PLANE"]      = 'AIRPLANE',
	["STATIC"]     = 'STRUCTURE',
}

local function lookupname(name, names)
	assert(name and type(name) == "string", "name must be provided")
	local newname = name
	local namelist = names or {}
	if namelist[name] ~= nil then
		newname = namelist[name]
	end
	return newname
end

local function createTable(tpl, ctx)
	local data = tpl.tpldata
	if data[ctx.category] == nil then
		data[ctx.category] = {}
	end
end

local function convertNames(data, names)
	data.name = lookupname(data.name, names)

	for _, unit in ipairs(data.units or {}) do
		unit.name = lookupname(unit.name, names)
	end

	if data.route then
		for _, wypt in ipairs(data.route.points or {}) do
			wypt.name = lookupname(wypt.name, names)
		end
	end
end

local function addOneStatic(tpl, _, grp, ctx)
	local tbl = {}
	createTable(tpl, ctx)
	tbl.data      = grp.units[1]
	tbl.data.dead = grp.dead
	tbl.countryid = ctx.countryid
	convertNames(tbl.data, tpl.names)
	table.insert(tpl.tpldata[ctx.category], tbl)
end

local function addOneGroup(tpl, _, grp, ctx)
	local tbl = {}
	createTable(tpl, ctx)
	tbl.data = grp
	tbl.countryid = ctx.countryid
	convertNames(tbl.data, tpl.names)
	table.insert(tpl.tpldata[ctx.category], tbl)
end

local function processCountry(tpl, side, ctry)
	local funcmap = {
		["HELICOPTER"] = addOneGroup,
		["SHIP"]       = addOneGroup,
		["VEHICLE"]    = addOneGroup,
		["PLANE"]      = addOneGroup,
		["STATIC"]     = addOneStatic,
	}

	local ctx = {}
	ctx.side      = side
	ctx.category  = "none"
	ctx.countryid = ctry.id

	for cat, _ in pairs(categorymap) do
		cat = string.lower(cat)
		if ctry[cat] and type(ctry[cat]) == 'table' and
		   ctry[cat].group then
			if tpl.coalition == nil then
				tpl.coalition = side
			end
			assert(tpl.coalition == side, "country("..ctry.id..") does not"..
				" belong to template.coalition("..tpl.coalition.."),"..
				" country belongs to "..side)
			ctx.category = cat
			utils.foreach(tpl,
				ipairs,
				funcmap[string.upper(cat)],
				ctry[cat].group,
				ctx)
		end
	end
end

local function processCoalition(tpl, side, coa)
	if side ~= 'red' and side ~= 'blue' and
	   type(coa) ~= 'table' then
		return
	end

	if coa.country == nil or type(coa.country) ~= 'table' then
		return
	end

	for _, ctry_data in ipairs(coa.country) do
		side = coalition.getCountryCoalition(ctry_data.id)
		processCountry(tpl, side, ctry_data)
	end
end

local STM = {}

--[[
-- Convert STM data format
--    stm = {
--      coalition = {
--        red/blue = {
--          country = {
--            # = {
--              id = country id
--              category = {
--                group = {
--                  # = {
--                    groupdata
--    }}}}}}}}
--
-- to an internal, simplier, storage format
--
--    tpldata = {
--      category = {
--        # = {
--          countryid = id,
--          data      = {
--            # group def members
--            dct_deathgoal = goalspec
--    }}}}
--
-- where category == {vehicle, plane, ...}
--
--]]

function STM.transform(stmdata)
	local template   = {}
	template.names   = stmdata.localization.DEFAULT
	template.name    = lookupname(stmdata.name, template.names)
	template.theater = lookupname(stmdata.theatre, template.names)
	template.desc    = lookupname(stmdata.desc, template.names)
	template.tpldata = {}

	for coa_key, coa_data in pairs(stmdata.coalition) do
		processCoalition(template, coa_key, coa_data)
	end
	template.names = nil
	return template
end

STM.categorymap = categorymap
return STM
