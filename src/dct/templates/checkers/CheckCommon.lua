-- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local utils   = require("libs.utils")
local dctenum = require("dct.enum")
local Check   = require("dct.templates.checkers.Check")

local assettypes = utils.mergetables({}, dctenum.assetTypeDeprecated)
assettypes = utils.mergetables(assettypes, dctenum.assetType)

local CheckCommon = class("CheckCommon", Check)
function CheckCommon:__init()
	Check.__init(self, "Common", {
		["objtype"] = {
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = assettypes,
			["description"] = [[
Defines the type of game object (Asset) that will be created from the
template. Allowed values can be found in `assetType` table.]],
		},
		["name"] = {
			["agent"] = true,
			["type"] = Check.valuetype.STRING,
			["description"] =
			"",
		},
		["uniquenames"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] =
			"",
		},
		["ignore"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] =
			"",
		},
		["immortal"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
Set all unit groups in the template to be immortal.]],
		},
		["regenerate"] = {
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] =
			"",
		},
		["priority"] = {
			["deprecated"] = true,
			["default"] = 1000,
			["type"] = Check.valuetype.INT,
			["description"] =
			"",
		},
		["intel"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] =
			"",
		},
		["spawnalways"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] =
			"",
		},
		["cost"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] =
			"",
		},
		["desc"] = {
			["default"] = "false",
			["type"] = Check.valuetype.STRING,
			["description"] =
			"",
		},
		["codename"] = {
			["agent"] = true,
			["default"] = dctenum.DEFAULTCODENAME,
			["type"] = Check.valuetype.STRING,
			["description"] =
			"",
		},
		["theater"] = {
			["default"] = env.mission.theatre,
			["type"] = Check.valuetype.STRING,
			["nodoc"] = true,
		},
		["subordinates"] = {
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
			["description"] =
			"",
		},
		["locationmethod"] = {
			["agent"] = true,
			["default"] = "false",
			["type"] = Check.valuetype.STRING,
			["description"] =
			"",
		},
		["displayname"] = {
			["default"] = dctenum.DEFAULTNAME,
			["type"] = Check.valuetype.STRING,
			["description"] = [[
Name to display to players which will be used to reference the agent
in any player facing UI. Depending on the asset type this name can be
dynamically generated.]],
		},
		["attackrange"] = {
			["default"] = dctenum.DEFAULTRANGE,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Distance at which the agent considers a target in-range, in meters.
For things like a squadron defines the maximum path distance the squadron
will accept from their home base to the target area.]],
		},
		["threats"] = {
			["default"] = {},
			["agent"] = true,
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
A list of DCS attributes that will be used to determine if a given
object is a threat to the agent.]],
		},
		["ammo"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
This resource allows a commander to resupply units in the field. Only
resource assets can provide resources and they are magically collected
at a rate of X units every 10 minutes and collected into a common
resource pool per region. Any spawner or generator agent can pull any or
all of a given resource from the common region resource pool.]],
		},
		["supply"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
This resource allows a commander to repair units and built new units.
Resource assets can provide resources and they are magically collected
at a rate of X units every 10 minutes and collected into a common
resource pool per region. Any spawner or generator agent can pull any or
all of a given resource from the common region resource pool.]],
		},
		["control"] = {
			["default"] = 0,
			["type"] = Check.valuetype.RANGE,
			["values"] = {0, 1},
			["description"] = [[
The value entered is the amount of total control influence the asset
exerts in the region after the ramp period. For example an airbase
in a moderate region may be able to influence .75 of the overall region.
The value is arbitrary and completely up to the campaign designer.
Control represents security over a given region, it also moderates the
level and type of objects that can be built in a region. Control has both
a buildup and falloff period.

Buildup rate:
Every 2 minutes 10% of the total influence is collected until the maximum
influence is reached.

Falloff rate:
Every 2 minutes a side's regional influence is reduced by 50%.]],
		},
	})
end

function CheckCommon:check(data)
	if dctenum.assetTypeDeprecated[string.upper(data.objtype)] ~= nil then
		dct.Logger.getByName("Template"):warn(
			"%s: is a deprecated objtype; file %s",
			tostring(data.objtype), tostring(data.filedct))
	end

	local ok, key, msg = Check.check(self, data)

	if not ok then
		return ok, key, msg
	end

	if data.uniquenames and data.codename ~= dctenum.DEFAULTCODENAME then
		return false, "codename",
		       "cannot be defined if uniquenames is true"
	end

	if data.uniquenames and data.locationmethod ~= "false" then
		return false, "locationmethod",
		       "cannot be defined if uniquenames is true"
	end

	data.cost = math.abs(data.cost)
	return true
end

return CheckCommon
