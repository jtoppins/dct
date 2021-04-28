--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

require("lfs")
local class = require("libs.class")
local utils = require("libs.utils")
local enum  = require("dct.enum")
local vector= require("dct.libs.vector")
local Goal  = require("dct.Goal")
local STM   = require("dct.templates.STM")

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

local function makeNamesUnique(data)
	for _, grp in ipairs(data) do
		grp.data.name = grp.data.name.." #"..
			dct.Theater.singleton():getcntr()
		for _, v in ipairs(grp.data.units or {}) do
			v.name = v.name.." #"..dct.Theater.singleton():getcntr()
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
	grp.data.unitId  = nil
	grp.data.start_time = 0
	grp.data.dct_deathgoal = goalFromName(grp.data.name, goaltype)
	if grp.data.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	grp.data.name = tpl.regionname.."_"..tpl.name.." "..tpl.coalition.." "..
		utils.getkey(Unit.Category, grp.category).." "..tostring(idx)

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

local function checkbldgdata(keydata, tpl)
	for _, bldg in ipairs(tpl[keydata.name]) do
		local bldgdata = {}
		bldgdata.countryid = 0
		bldgdata.category  = enum.UNIT_CAT_SCENERY
		bldgdata.data = {
			["dct_deathgoal"] = goalFromName(bldg.goal,
				Goal.objtype.SCENERY),
			["name"] = tostring(bldg.id),
		}
		local sceneryobject = { id_ = tonumber(bldgdata.data.name), }
		utils.mergetables(bldgdata.data,
			vector.Vector2D(Object.getPoint(sceneryobject)):raw())
		table.insert(tpl.tpldata, bldgdata)
		if bldgdata.data.dct_deathgoal ~= nil then
			tpl.hasDeathGoals = true
		end
	end
	return true
end

local function checkobjtype(keydata, tbl)
	if type(tbl[keydata.name]) == "number" and
		utils.getkey(enum.assetType, tbl[keydata.name]) ~= nil then
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
		utils.getkey(coalition.side, tbl[keydata.name]) ~= nil then
		return true
	elseif type(tbl[keydata.name]) == "string" and
		coalition.side[string.upper(tbl[keydata.name])] ~= nil then
		tbl[keydata.name] = coalition.side[string.upper(tbl[keydata.name])]
		return true
	end
	return false
end

local function checktakeoff(keydata, tpl)
	local allowed = {
		["inair"]   = AI.Task.WaypointType.TURNING_POINT,
		["runway"]  = AI.Task.WaypointType.TAKEOFF,
		["parking"] = AI.Task.WaypointType.TAKEOFF_PARKING,
	}

	local val = allowed[tpl[keydata.name]]
	if val then
		tpl[keydata.name] = val
		return true
	end
	return false
end

local function checkrecovery(keydata, tpl)
	local allowed = {
		["terminal"] = true,
		["land"]     = true,
		["taxi"]     = true,
	}

	if allowed[tpl[keydata.name]] then
		return true
	end
	return false
end

local function checkmsntype(keydata, tbl)
	local msnlist = {}
	for _, msntype in pairs(tbl[keydata.name]) do
		local msnstr = string.upper(msntype)
		if type(msntype) ~= "string" or
		   enum.missionType[msnstr] == nil then
			return false
		end
		msnlist[msnstr] = enum.missionType[msnstr]
	end
	tbl[keydata.name] = msnlist
	return true
end

local function check_payload_limits(keydata, tbl)
	local newlimits = {}
	for wpncat, val in pairs(tbl[keydata.name]) do
		local w = enum.weaponCategory[string.upper(wpncat)]
		if w == nil then
			return false
		end
		newlimits[w] = val
	end
	tbl[keydata.name] = newlimits
	return true
end


local function getkeys(objtype)
	local notpldata = {
		[enum.assetType.AIRSPACE]       = true,
		[enum.assetType.AIRBASE]        = true,
		[enum.assetType.SQUADRONPLAYER] = true,
	}
	local defaultintel = 0
	if objtype == enum.assetType.AIRBASE then
		defaultintel = 5
	end

	local keys = {
		{
			["name"]  = "name",
			["type"]  = "string",
		}, {
			["name"]  = "regionname",
			["type"]  = "string",
		}, {
			["name"]  = "coalition",
			["type"]  = "number",
			["check"] = checkside,
		}, {
			["name"]    = "uniquenames",
			["type"]    = "boolean",
			["default"] = false,
		}, {
			["name"]    = "ignore",
			["type"]    = "boolean",
			["default"] = false,
		}, {
			["name"]    = "regenerate",
			["type"]    = "boolean",
			["default"] = false,
		}, {
			["name"]    = "priority",
			["type"]    = "number",
			["default"] = enum.assetTypePriority[objtype] or 1000,
		}, {
			["name"]    = "regionprio",
			["type"]    = "number",
		}, {
			["name"]    = "intel",
			["type"]    = "number",
			["default"] = defaultintel,
		}, {
			["name"]    = "spawnalways",
			["type"]    = "boolean",
			["default"] = false,
		}, {
			["name"]    = "cost",
			["type"]    = "number",
			["default"] = 0,
		}, {
			["name"]    = "desc",
			["type"]    = "string",
			["default"] = "false",
		},{
			["name"]    = "codename",
			["type"]    = "string",
			["default"] = "default codename",
		},
	}

	if notpldata[objtype] == nil then
		table.insert(keys, {
			["name"]  = "tpldata",
			["type"]  = "table",
			["default"] = {},
			["check"] = checktpldata,})
		table.insert(keys, {
			["name"]    = "buildings",
			["type"]    = "table",
			["default"] = {},
			["check"] = checkbldgdata,})
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
			["name"]  = "subordinates",
			["type"]  = "table", })
		table.insert(keys, {
			["name"]    = "takeofftype",
			["type"]    = "string",
			["default"] = "inair",
			["check"]   = checktakeoff,})
		table.insert(keys, {
			["name"]    = "recoverytype",
			["type"]    = "string",
			["default"] = "terminal",
			["check"]   = checkrecovery,})
	end

	if objtype == enum.assetType.SQUADRONPLAYER then
		table.insert(keys, {
			["name"]    = "ato",
			["type"]    = "table",
			["check"]   = checkmsntype,
			["default"] = enum.missionType,
		})

		table.insert(keys, {
			["name"]    = "payloadlimits",
			["type"]    = "table",
			["check"]   = check_payload_limits,
			["default"] = dct.settings.payloadlimits,
		})
	end

	if objtype == enum.assetType.SQUADRONPLAYER or
	   objtype == enum.assetType.AIRBASE then
		table.insert(keys, {
			["name"]  = "players",
			["type"]  = "table",
			["default"] = {},
		})
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
	utils.checkkeys({ [1] = {
		["name"]  = "objtype",
		["type"]  = "string",
		["check"] = checkobjtype,
	},}, self)

	utils.checkkeys(getkeys(self.objtype), self)
end

-- PUBLIC INTERFACE
function Template:copyData()
	local copy = utils.deepcopy(self.tpldata)
	if self.uniquenames == true then
		makeNamesUnique(copy)
	end
	return copy
end

function Template.fromFile(region, dctfile, stmfile)
	assert(region ~= nil, "region is required")
	assert(dctfile ~= nil, "dctfile is required")

	local template = utils.readlua(dctfile)
	if template.metadata then
		template = template.metadata
	end
	template.regionname = region.name
	template.regionprio = region.priority
	template.path = dctfile
	if template.desc == "false" then
		template.desc = nil
	end
	if stmfile ~= nil then
		template = utils.mergetables(
			STM.transform(utils.readlua(stmfile, "staticTemplate")),
			template)
	end
	return Template(template)
end

return Template
