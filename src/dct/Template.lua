--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

require("lfs")
local class = require("libs.class")
local utils = require("libs.utils")
local enum  = require("dct.enum")
local dctutils = require("dct.utils")
local Goal  = require("dct.Goal")
local STM   = require("dct.STM")

--[[
-- represents the amount of damage that can be taken before
-- that state is no longer considered valid.
-- example:
--   goal: damage unit to 85% of original health (aka incapacitate)
--
--   unit.health = .85
--   goal = 85
--   damage_taken = (1 - unit.health) * 100 = 15
--
--   if damage_taken > goal = goal met, in this case we have
--   not met our greater than 85% damage.
--]]
local damage = {
	["UNDAMAGED"]     = 10,
	["DAMAGED"]       = 45,
	["INCAPACITATED"] = 75,
	["DESTROYED"]     = 90,
}

--[[
-- generates a death goal from an object's name by
-- using keywords.
--]]
local function goalFromName(name, objtype)
	local goal = {}
	local goalvalid = false
	name = string.upper(name)

	for k, v in pairs(Goal.priority) do
		local index = string.find(name, k)
		if index ~= nil then
			goal.priority = v
			goalvalid = true
			break
		end
	end

	for k, v in pairs(damage) do
		local index = string.find(name, k)
		if index ~= nil then
			goal.value = v
			goalvalid = true
			break
		end
	end

	if not goalvalid then
		return nil
	end
	if goal.priority == nil then
		goal.priority = Goal.priority.PRIMARY
	end
	if goal.value == nil then
		goal.value = damage.INCAPACITATED
	end
	goal.objtype  = objtype
	goal.goaltype = Goal.goaltype.DAMAGE
	return goal
end

-- unique name counter, allows us to generate names that are always unique
-- TODO: this value would need to be saved for mission persistance
local namecntr = 1000

local function getcntr()
	namecntr = namecntr + 1
	return namecntr
end

local function makeNamesUnique(data)
	for _, grp in ipairs(data) do
		grp.data.name = grp.data.name .. " #" .. getcntr()
		for _, v in ipairs(grp.data.units or {}) do
			v.name = v.name .. " #" .. getcntr()
		end
	end
end

local function overrideUnitOptions(unit, key, tpl, basename)
	if unit.playerCanDrive ~= nil then
		unit.playerCanDrive = false
	end
	unit.unitId = nil
	unit.dct_deathgoal = goalFromName(unit.name, Goal.objtype.UNIT)
	if unit.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	unit.name = basename.."-"..key
end

local function overrideGroupOptions(grp, idx, tpl)
	local opts = {
		visible        = true,
		uncontrollable = true,
		lateActivation = false,
	}

	for k, v in pairs(opts) do
		if grp[k] ~= nil then grp[k] = v end
	end

	local goaltype = Goal.objtype.GROUP
	if grp.category == Unit.Category.STRUCTURE then
		goaltype = Goal.objtype.STATIC
	end

	grp.data.groupId = nil
	grp.data.start_time = 0
	grp.data.dct_deathgoal = goalFromName(grp.data.name, goaltype)
	if grp.data.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	grp.data.name = tpl.regionname.."_"..tpl.name.." "..tpl.coalition.." "..
		dctutils.getkey(Unit.Category, grp.category).." "..tostring(idx)

	for i, unit in ipairs(grp.data.units or {}) do
		overrideUnitOptions(unit, i, tpl, grp.data.name)
	end
end

local function checktpldata(_, tpl)
	-- loop over all tpldata and process names and existence of deathgoals
	for idx, grp in ipairs(tpl.tpldata) do
		overrideGroupOptions(grp, idx, tpl)
	end
	return true
end

local function checkobjtype(keydata, tbl)
	if type(tbl[keydata.name]) == "number" and
		dctutils.getkey(enum.assetType, tbl[keydata.name]) ~= nil then
		return true
	elseif type(tbl[keydata.name]) == "string" and
		enum.assetType[string.upper(tbl[keydata.name])] ~= nil then
		tbl[keydata.name] = enum.assetType[string.upper(tbl[keydata.name])]
		return true
	end
	return false
end

local function checkside(keydata, tbl)
	if type(tbl[keydata.name]) == "number" and
		dctutils.getkey(coalition.side, tbl[keydata.name]) ~= nil then
		return true
	elseif type(tbl[keydata.name]) == "string" and
		coalition.side[string.upper(tbl[keydata.name])] ~= nil then
		tbl[keydata.name] = coalition.side[string.upper(tbl[keydata.name])]
		return true
	end
	return false
end

local function getkeys(objtype)
	local keys = {
		[1] = {
			["name"]  = "name",
			["type"]  = "string",
		},
		[2] = {
			["name"]  = "regionname",
			["type"]  = "string",
		},
		[3] = {
			["name"]  = "coalition",
			["type"]  = "number",
			["check"] = checkside,
		},
		[4] = {
			["name"]    = "uniquenames",
			["type"]    = "boolean",
			["default"] = false,
		},
		[5] = {
			["name"]    = "priority",
			["type"]    = "number",
			["default"] = enum.assetTypePriority[objtype] or 1000,
		},
		[6] = {
			["name"]    = "primary",
			["type"]    = "boolean",
			["default"] = false,
		},
		[7] = {
			["name"]    = "intel",
			["type"]    = "number",
			["default"] = 0,
		},
		[8] = {
			["name"]    = "spawnalways",
			["type"]    = "boolean",
			["default"] = false,
		},
	}

	if objtype ~= enum.assetType.AIRSPACE and
		objtype ~= enum.assetType.AIRBASE then
		table.insert(keys, {
			["name"]  = "tpldata",
			["type"]  = "table",
			["check"] = checktpldata,})
	end

	if objtype == enum.assetType.AIRSPACE then
		table.insert(keys, {
			["name"]  = "location",
			["type"]  = "table",})
		table.insert(keys, {
			["name"]  = "volume",
			["type"]  = "table", })
	end

	if objtype == enum.assetType.AIRBASE then
		table.insert(keys, {
			["name"]  = "defenses",
			["type"]  = "string", })
	end

	return keys
end

--[[
--  Template class
--    base class that reads in a template file and organizes
--    the data for spawning.
--
--    properties
--    ----------
--      * objtype   - represents an abstract type of asset
--      * name      - name of the template
--      * region    - the region name the template belongs too
--      * coalition - which coalition the template belongs too
--                    templates can only belong to one side and
--                    one side only
--      * desc      - description of the template, used to generate
--		              mission breifings from
--
--    Storage
--    -------
--    tpldata = {
--      # = {
--          category = Unit.Category
--          countryid = id,
--          data      = {
--            # group def members
--            dct_deathgoal = goalspec
--    }}}
--
--    DCT File
--    --------
--      Required Keys:
--        * objtype - the kind of "game object" the template represents
--
--      Optional Keys:
--        * uniquenames - when a Template's data is copied the group and
--              unit names a guaranteed to be unique if true
--        * priority - the relative importance of the template in relation
--              to other templates
--        * rank - determines if the template is a "primary", "secondary"
--              or "tertiary" target.
--        * base - [Required] only used if the 'objtype' represents some
--              sort of base object that needs to be associated with a
--              DCS base object, the name of the DCS base is put here.
--
--]]
local Template = class()
function Template:__init(data)
	assert(data and type(data) == "table", "value error: data required")
	self.hasDeathGoals = false
	utils.mergetables(self, utils.deepcopy(data))
	self:validate()

	self.fromFile = nil
end

function Template:validate()
	dctutils.checkkeys({ [1] = {
		["name"]  = "objtype",
		["type"]  = "string",
		["check"] = checkobjtype,
	},}, self)

	dctutils.checkkeys(getkeys(self.objtype), self)
end

-- PUBLIC INTERFACE
function Template:copyData()
	local copy = utils.deepcopy(self.tpldata)
	if self.uniquenames == true then
		makeNamesUnique(copy)
	end
	return copy
end

function Template.fromFile(regionname, dctfile, stmfile)
	assert(regionname ~= nil, "regionname is required")
	assert(dctfile ~= nil, "dctfile is required")

	local template = utils.readlua(dctfile, "metadata")
	template.regionname = regionname
	template.path = dctfile
	if stmfile ~= nil then
		template = utils.mergetables(template,
			STM.transform(utils.readlua(stmfile, "staticTemplate")))
	end
	return Template(template)
end

return Template
