--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

require("lfs")
local class = require("libs.class")
local utils = require("libs.utils")
local enum  = require("dct.enum")
local Goal  = require("dct.Goal")
local STM   = require("dct.STM")

local function checktype(val)
	local allowed = enum.assetType
	if type(val) == "number" then
		return true
	elseif type(val) == "string" then
		return (allowed[string.upper(val)] ~= nil)
	end
	return false
end

local function settype(tbl, key)
	local allowed = enum.assetType
	local t = type(tbl[key])
	if t == "string" then
		tbl[key] = allowed[string.upper(tbl[key])]
	end
end

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
	for _, cat_data in pairs(data) do
		for _, grp in ipairs(cat_data) do
			grp.data.name = grp.data.name .. " #" .. getcntr()
			for _, v in ipairs(grp.data.units or {}) do
				v.name = v.name .. " #" .. getcntr()
			end
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

local function overrideGroupOptions(grp, idx, tpl, category)
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

	local goaltype = Goal.objtype.GROUP
	if string.lower(category) == "static" then
		goaltype = Goal.objtype.STATIC
	end

	grp.groupId = nil
	grp.start_time = 0
	grp.dct_deathgoal = goalFromName(grp.name, goaltype)
	if grp.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	grp.name = tpl.regionname.."_"..tpl.name.." "..tpl.coalition.." "..
		category.." "..tostring(idx)

	for i, unit in ipairs(grp.units or {}) do
		overrideUnitOptions(unit, i, tpl, grp.name)
	end
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
--      category = {
--        # = {
--          countryid = id,
--          data      = {
--            # group def members
--            dct_deathgoal = goalspec
--    }}}}
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
	local requiredkeys = {
		["objtype"]  = {
			["check"] = checktype,
			["set"]   = settype,
		},
		["tpldata"] = {
			["check"] = function (t) return type(t) == "table" end,
		},
		["coalition"] = {
			["check"] = function (t) return t ~= nil end,
		},
	}

	for key, val in pairs(requiredkeys) do
		if self[key] == nil or
		   not val["check"](self[key]) then
			assert(false, "invalid or missing option '"..key.."'")
		else
			if val["set"] ~= nil and type(val["set"]) == "function" then
				val["set"](self, key)
			end
		end
	end

	-- order is important here otherwise the default priority will be
	-- nil because objtype will have not been converted from a string
	-- to its numerical value
	local optionalkeys = {
		["uniquenames"] = {
			["type"]    = "boolean",
			["default"] = false,
		},
		["priority"] = {
			["type"]    = "number",
			["default"] = enum.assetTypePriority[self.objtype],
		},
		["rank"] = {
			["type"]    = "number",
			["default"] = Goal.priority.SECONDARY,
		},
		["regionname"] = {
			["type"]    = "string",
			["default"] = env.mission.theatre,
		},
	}

	for key, data in pairs(optionalkeys) do
		if self[key] == nil or
		   type(self[key]) ~= data.type then
			self[key] = data.default
		end
	end

	-- loop over all tpldata and process names and existence of deathgoals
	for cat, cat_data in pairs(self.tpldata) do
		for idx, grp in ipairs(cat_data) do
			overrideGroupOptions(grp.data, idx, self, cat)
		end
	end
end

-- PUBLIC INTERFACE
function Template:copyData()
	local copy = utils.deepcopy(self.tpldata)
	if self.uniquenames ~= true then
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
