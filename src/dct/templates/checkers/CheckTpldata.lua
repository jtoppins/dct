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
	unit.dct_deathgoal = goalFromName(unit.name, Goal.objtype.UNIT)
	if unit.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end

	if tpl.overwrite == true then
		unit.unitId = nil
		unit.name = basename.."-"..key

		if unit.playerCanDrive ~= nil then
			unit.playerCanDrive = false
		end
	end

	if tpl.unitTypeCnt[unit.type] == nil then
		tpl.unitTypeCnt[unit.type] = 0

		local unitdesc = Unit.getDescByName(unit.type)
		if unitdesc ~= nil then
			utils.mergetables(tpl.attributes, unitdesc.attributes)
		end
	end
	tpl.unitTypeCnt[unit.type] = tpl.unitTypeCnt[unit.type] + 1
end

local _opts = {
	visible        = true,
	uncontrollable = true,
	lateActivation = false,
}

local function overrideGroupOptions(grp, idx, tpl)
	if grp.category == dctenum.UNIT_CAT_SCENERY then
		return
	end

	local objtype = Goal.objtype.GROUP
	if grp.category == Unit.Category.STRUCTURE then
		objtype = Goal.objtype.STATIC
	end

	grp.data.dct_deathgoal = goalFromName(grp.data.name, objtype)
	if grp.data.dct_deathgoal ~= nil then
		tpl.hasDeathGoals = true
	end

	if tpl.overwrite == true then
		for k, v in pairs(_opts) do
			if grp.data[k] ~= nil then grp.data[k] = v end
		end

		grp.data.start_time = 0
		grp.data.groupId = nil
		grp.data.unitId  = nil

		grp.data.name = string.format("%s %d %s %d",
			tpl.name,
			coalition.getCountryCoalition(grp.countryid),
			utils.getkey(Unit.Category, grp.category), idx)
	end

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
			["description"] = [[
For templates that are not associated with an STM file the format of
`tpldata` follows:

```lua
tpldata = {
	# = {
		category  = Unit.Category,
		countryid = id,
		data      = {
			# group def members
			dct_deathgoal = goalspec
		},
	}
}
```

`tpldata` is a LUA list where each list entry is as shown above; `category`,
`countryid`, and `data`.

 * `category` - is a value from the `Unit.Category` table
 * `countryid` - is the numerical id of the country the
   static/group belongs to
 * `data` - is the actual static/group definition in a format that is
   expected by `coalition.addGroup()` and `coalition.addStatic()`]],
		},
		["buildings"] = {
			["default"] = {},
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
Allows the campaign designer to specify scenery objects as part of the
template. The definition is a list of scenery objects that should
be included as part of the template, an example from the Persian Gulf
map;

```lua
buildings = {
	{
		["name"] = "building 1",
		["goal"] = "primary destroyed",
		["id"]   = 109937143,
	},
}
```

Where `name` is the name of the scenery object (is arbitrary and only
referenced in DCT for error reporting), `goal` conforms to the textual
[goalspec](#death-goal-specification-goalspec), and `id` is the map
specific object id which can be obtained from the mission editor.]],
		},
		["unitTypeCnt"] = {
			["nodoc"] = true,
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
		},
		["hasDeathGoals"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
		},
		["overwrite"] = {
			["nodoc"] = true,
			["default"] = true,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
Controls if various items of the template data is removed from the
template.]],
		},
		["rename"] = {
			["nodoc"] = true,
			["default"] = true,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
Controls if the name of the generated Agent gets renamed to include the
region name.]]
		},
	}, [[Describes the actual DCS object that will be spawned/tracked
in association with an asset created from this template.]])
end

local notpldata = {
	[dctenum.assetType.AIRBASE]     = true,
	[dctenum.assetType.SQUADRON]    = true,
}

function CheckTpldata:check(data)
	if notpldata[data.objtype] ~= nil then
		return true
	end

	check_buildings(data)

	local ok, key, msg = Check.check(self, data)
	if not ok then
		return ok, key, msg
	end

	-- loop over all tpldata and process names and existence of
	-- deathgoals
	for idx, grp in ipairs(data.tpldata) do
		overrideGroupOptions(grp, idx, data)
	end

	-- get the max speed for the template which is the minimum
	-- speedMax entry for all unit types in the template
	local maxspeed = 100000000
	for typename, _ in pairs(data.unitTypeCnt) do
		local desc = Unit.getDescByName(typename)
		maxspeed = math.min(maxspeed, desc.speedMax)
	end
	data.speedMax = maxspeed

	return true
end

return CheckTpldata
