--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local vector   = require("dct.libs.vector")
local Goal     = require("dct.assets.DeathGoals")
local Check    = require("dct.templates.checkers.Check")

-- represents the amount of damage that can be taken before
-- that state is no longer considered valid.
-- example:
--   goal: damage unit to 85% of original health (aka incapacitate)
--
--   unit.health = .85
--   goal = .85
--   damage_taken = (1 - unit.health) = .15
--
--   if damage_taken > goal = goal met, in this case we have
--   not met our greater than 85% damage.
local damage = {
	["UNDAMAGED"]     = .1,
	["DAMAGED"]       = .45,
	["INCAPACITATED"] = .75,
	["DESTROYED"]     = .9,
}

-- generates a death goal from an object's name by using keywords.
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
	return goal
end

local function overrideUnitOptions(unit, key, tpl, basename)
	local unitdesc = Unit.getDescByName(unit.type)

	if unit.playerCanDrive ~= nil then
		unit.playerCanDrive = false
	end

	unit.unitId = nil
	unit.dct_deathgoal = goalFromName(unit.name, Goal.objtype.UNIT)
	if unit.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	unit.name = basename.."-"..key

	if tpl.unitTypeCnt[unit.type] == nil then
		tpl.unitTypeCnt[unit.type] = 0
	end
	tpl.unitTypeCnt[unit.type] = tpl.unitTypeCnt[unit.type] + 1

	if unitdesc ~= nil then
		utils.mergetables(tpl.attributes, unitdesc.attributes)
	end
end

local function overrideGroupOptions(grp, idx, tpl)
	if grp.category == dctenum.UNIT_CAT_SCENERY then
		return
	end

	local opts = {
		visible        = true,
		uncontrollable = true,
		lateActivation = false,
	}

	for k, v in pairs(opts) do
		if grp[k] ~= nil then grp[k] = v end
	end

	local objtype = Goal.objtype.GROUP
	if grp.category == Unit.Category.STRUCTURE then
		objtype = Goal.objtype.STATIC
	end

	grp.data.groupId = nil
	grp.data.unitId  = nil
	grp.data.start_time = 0
	grp.data.dct_deathgoal = goalFromName(grp.data.name, objtype)
	if grp.data.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end
	local side = coalition.getCountryCoalition(grp.countryid)
	grp.data.name = string.format("%s %d %s %d",
		tpl.name, side,
		utils.getkey(Unit.Category, grp.category), idx)

	for i, unit in ipairs(grp.data.units or {}) do
		overrideUnitOptions(unit, i, tpl, grp.data.name)
	end
end

local function check_buildings(data)
	local key = "buildings"

	if data[key] ~= nil and next(data[key]) ~= nil and
	   data.tpldata == nil then
		data.tpldata = {}
	end

	for _, bldg in ipairs(data[key] or {}) do
		local bldgdata = {}
		bldgdata.category = dctenum.UNIT_CAT_SCENERY
		bldgdata.data = {
			["dct_deathgoal"] = goalFromName(bldg.goal,
				Goal.objtype.SCENERY),
			["name"] = tostring(bldg.id),
		}
		local sceneryobject = { id_ = tonumber(bldgdata.data.name), }
		utils.mergetables(bldgdata.data,
			vector.Vector2D(Object.getPoint(sceneryobject)):raw())
		table.insert(data.tpldata, bldgdata)
		if bldgdata.data.dct_deathgoal ~= nil then
			data.hasDeathGoals = true
		end
	end
end

local CheckTpldata = class("CheckTpldata", Check)
function CheckTpldata:__init()
	Check.__init(self, "Template Data", {
		["tpldata"] = {
			["agent"] = true,
			["type"]  = Check.valuetype.TABLE,
			["description"] =
			"",
		},
		["buildings"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] =
			"",
		},
		["attributes"] = {
			["agent"] = true,
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] =
			"",
		},
		["hasDeathGoals"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
		},
	})
end

local notpldata = {
	[dctenum.assetType.AIRBASE]     = true,
	[dctenum.assetType.SQUADRONPLAYER]    = true,
	-- player groups do have tpldata, it is here as we do not
	-- want to remove any data from the template definition
	[dctenum.assetType.PLAYER] = true,
}

function CheckTpldata:check(data)
	if notpldata[data.objtype] ~= nil then
		return true
	end

	data.hasDeathGoals = false

	if data.attributes == nil then
		data.attributes = {}
	end

	if data.unitTypeCnt == nil then
		data.unitTypeCnt = {}
	end

	check_buildings(data)

	if data.tpldata == nil then
		return false, "tpldata", Check.reasontext[Check.rc.REQUIRED]
	end

	-- loop over all tpldata and process names and existence of
	-- deathgoals
	for idx, grp in ipairs(data.tpldata) do
		overrideGroupOptions(grp, idx, data)
	end

	return true
end

return CheckTpldata
