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

local function convertNames(data, namefunc)
	data.name = namefunc(data.name)

	for _, unit in ipairs(data.units or {}) do
		unit.name = namefunc(unit.name)
	end

	if data.route then
		for _, wypt in ipairs(data.route.points or {}) do
			wypt.name = namefunc(wypt.name)
		end
	end
end

local function modifyStatic(grpdata, _, dcscategory)
	if dcscategory ~= Unit.Category.STRUCTURE then
		return grpdata
	end
	local grpcpy = utils.deepcopy(grpdata.units[1])
	grpcpy.dead = grpdata.dead
	return grpcpy
end

local function processCategory(grplist, cattbl, cntryid, dcscategory, ops)
	if type(cattbl) ~= 'table' or cattbl.group == nil then
		return
	end
	for _, grp in ipairs(cattbl.group) do
		if ops.grpfilter == nil or
			ops.grpfilter(grp, cntryid, dcscategory) == true then
			if type(ops.grpmodify) == 'function' then
				grp = ops.grpmodify(grp, cntryid, dcscategory)
			end
			local grptbl = {
				["data"]      = utils.deepcopy(grp),
				["countryid"] = cntryid,
				["category"]  = dcscategory,
			}
			convertNames(grptbl.data, ops.namefunc)
			table.insert(grplist, grptbl)
		end
	end
end


local STM = {}

-- return all groups matching `grpfilter` from `tbl`
-- grpfilter(grpdata, countryid, Unit.Category)
--   returns true if the filter matches and the group entry should be kept
-- grpmodify(grpdata, countryid, Unit.Category)
--   returns a copy of the group data modified as needed
-- always returns a table, even if it is empty
function STM.processCoalition(tbl, namefunc, grpfilter, grpmodify)
	assert(type(tbl) == 'table', "value error: `tbl` must be a table")
	assert(tbl.country ~= nil and type(tbl.country) == 'table',
		"value error: `tbl` must have a member `country` that is a table")

	local grplist = {}
	if namefunc == nil then
		namefunc = env.getValueDictByKey
	end
	local ops = {
		["namefunc"] = namefunc,
		["grpfilter"] = grpfilter,
		["grpmodify"] = grpmodify,
	}

	for _, cntrytbl in ipairs(tbl.country) do
		for cat, unitcat in pairs(categorymap) do
			processCategory(grplist,
				cntrytbl[string.lower(cat)],
				cntrytbl.id,
				Unit.Category[unitcat],
				ops)
		end
	end
	return grplist
end


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
--      [#] = {
--        category  = Unit.Category[STM_category],
--        countryid = id,
--        data      = {
--            # group definition
--            dct_deathgoal = goalspec
--    }}}
--]]

function STM.transform(stmdata)
	local template   = {}
	local lookupname =  function(name)
		assert(name and type(name) == "string",
			"value error: name must be provided and a string")
		local newname = name
		local namelist = stmdata.localization.DEFAULT
		if namelist[name] ~= nil then
			newname = namelist[name]
		end
		return newname
	end
	local trackUniqueCoalition = function(_, cntryid, _)
		local side = coalition.getCountryCoalition(cntryid)
		if template.coalition == nil then
			template.coalition = side
		end
		assert(template.coalition == side,
			"runtime error: invalid template STM; country("..cntryid..")"..
			" does not belong to template.coalition("..template.coalition..
			"), country belongs to "..side)
		return true
	end

	template.name    = lookupname(stmdata.name)
	template.theater = lookupname(stmdata.theatre)
	template.desc    = lookupname(stmdata.desc)
	template.tpldata = {}

	for _, coa_data in pairs(stmdata.coalition) do
		for _, grp in ipairs(STM.processCoalition(coa_data,
				lookupname,
				trackUniqueCoalition,
				modifyStatic)) do
			table.insert(template.tpldata, grp)
		end
	end
	return template
end

STM.categorymap = categorymap
return STM
