-- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local utils   = require("libs.utils")
local dctenum = require("dct.enum")
local dctutils= require("dct.libs.utils")
local Check   = require("dct.templates.checkers.Check")

local ishq = {
	[dctenum.assetType.SQUADRON] = true,
	[dctenum.assetType.ARMYGROUP] = true,
	[dctenum.assetType.FLEET] = true,
}

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
template. Allowed values can be found in `assetType` table.

%VALUES%]],
		},
		["name"] = {
			["agent"] = true,
			["type"] = Check.valuetype.STRING,
			["description"] = [[
The name of the template. This name can be used to lookup the template from
the Region object. If the template uses an STM file then the name field of
the STM template will be used. This name field is editable in the mission
editor. If the template is an airbase type the name must reference an airbase
object in the game world or define a tpldata to spawn a new airbase. This
airbase validation is not done at template definition time and is instead
done at asset creation time, thus it is a non-fatal error generating a
warning in the log file. The asset will not be created if the name or tpldata
is incorrect or does not exist.]],
		},
		["attributes"] = {
			["agent"] = true,
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
Contains all DCS unit type attributes for all unit types that make up the asset.
This list also contains DCT specific attributes that may characterize the asset
at a meta level. Such as an asset that represents a base or strategic target.]]
		},
		["uniquenames"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
When a template can represent more than one instance of an Asset this
attribute should be set to `true` so when a new Asset is created the names
of the DCS objects are made unique. This way when the DCS objects are
dynamically spawned DCS will not despawn previously spawned objects because
they have the same name.]],
		},
		["ignore"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
Assets generated from templates with this attribute set to true will be
ignored by the DCT AI. This includes scheduling the asset to be assigned
as a target to a player. This will also make any units spawned by the asset
to be ignored by the DCS AI.]],
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
			["description"] = [[
Forces an asset on campaign state reload to reset its `tpldata` to the
original state when the asset was created.]],
		},
		["exclusion"] = {
			["default"] = "",
			["type"] = Check.valuetype.STRING,
			["description"] = [[
Used to mark templates that should not be spawned together. If the templates
have the same string value the templates will be grouped together and only
one template from the exclusion group will be selected. All other members
of the group will be ignored.]],
		},
		["priority"] = {
			["deprecated"] = true,
			["default"] = 1000,
			["type"] = Check.valuetype.INT,
			["description"] = [[
This field defines the relative priority to other templates/assets within
the region. A lower non-negative number means higher priority.]],
		},
		["intel"] = {
			["default"] = 0,
			["type"] = Check.valuetype.RANGE,
			["values"] = {0, dctutils.INTELMAX},
			["description"] = [[
Defines the initial amount of 'intel' the opposing side knows about any assets
generated from the template. The intel value is a direct representation to how
many decimal places the location of the asset will be truncated to.]],
		},
		["spawnalways"] = {
			["default"] = false,
			["type"] = Check.valuetype.BOOL,
			["description"] = [[
Used to identify templates that should always be spawned, the value should
always be 'true' or removed from the template definition.]],
		},
		["cost"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
The amount of tickets an asset generated from this template is worth.
With the ticket system each side has a given amount of tickets they can
lose. An asset with a cost value will deduct against this per-side ticket
pool. See the [tickets](#tickets) section for more information.]],
		},
		["desc"] = {
			["default"] = "false",
			["type"] = Check.valuetype.STRING,
			["description"] = [[
This is a text string field used to provide the 'target briefing' text when
a mission is assigned to a player. This text can use string replacement to
make certain parts of the message variable, the replacement fields are:

 * `LOCATIONMETHOD` - provides a randomly selected description of how the
   target was discovered.
 * `TOT` - replaces with the expected time-on-target]],
		},
		["codename"] = {
			["agent"] = true,
			["default"] = dctenum.DEFAULTCODENAME,
			["type"] = Check.valuetype.STRING,
			["description"] = [[
A static codename can be assigned to a template overriding the normally
random codename. Codenames are displayed in mission briefings and other
player UI elements.]],
		},
		["theater"] = {
			["default"] = env.mission.theatre,
			["type"] = Check.valuetype.STRING,
			["nodoc"] = true,
		},
		["basedat"] = {
			["agent"] = true,
			["default"] = "",
			["type"] = Check.valuetype.STRING,
			["description"] = [[
The name of the base at which this template is based at. For a squadron this
would be the airbase the squadron is based at. In the case of a squadron the
value must be a string that when passed to `Airbase.getByName(<name>)` returns
a DCS Airbase object.]],
		},
		["subordinates"] = {
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
A list of template names that will be converted into DCT assets. These
templates are usually base defenses or squadrons but there is nothing
preventing the designer from spawning additional assets with this list.]],
		},
		["locationmethod"] = {
			["agent"] = true,
			["default"] = "false",
			["type"] = Check.valuetype.STRING,
			["description"] = [[
Allows designers to enter a static string that is supposed to describe how the
asset was discovered.]],
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
		["speedMax"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["nodoc"] = true,
			["description"] = [[
The maximum speed of the slowest unit in the the template. Otherwise can
be used as a switch to not include various features of an Agent, like
movement actions if speedMax is zero.]]
		},
		["debug"] = {
			["default"] = 0,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Applies the DebugSensor to the Agent to periodically display debug
data about the agent. If the value is greater than zero it will enable
debug and set the refresh rate for the sensor in seconds.]],
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
	}, [[This section describes attributes common or mostly common to
all template types.]])
end

function CheckCommon:checkDefaults(data)
	if data.uniquenames and data.codename ~= dctenum.DEFAULTCODENAME then
		return false, "codename",
		       "cannot be defined if uniquenames is true"
	end

	if data.uniquenames and data.locationmethod ~= "false" then
		return false, "locationmethod",
		       "cannot be defined if uniquenames is true"
	end

	if data.airbase ~= nil and data.basedat == "" then
		data.basedat = data.airbase
	end

	if data.basedat == "" then
		if ishq[data.objtype] then
			return false, "basedat",
			       "required for headquarters assets"
		else
			data.basedat = nil
		end
	end
	return true
end

function CheckCommon:check(data)
	if dctenum.assetTypeDeprecated[string.upper(data.objtype)] ~= nil then
		dct.Logger.getByName("Template"):warn(
			"%s: is a deprecated objtype; file %s",
			tostring(data.objtype), tostring(data.filedct))
	end

	for _, check in ipairs({ Check.check,
				 self.checkDefaults, }) do
		local ok, key, msg = check(self, data)
		if not ok then
			return ok, key, msg
		end
	end

	if data.exclusion == "" then
		data.exclusion = nil
	end

	-- convert subordinate list to a set
	local subs = {}
	for _, name in pairs(data.subordinates) do
		subs[name] = true
	end
	data.subordinates = subs

	data.cost = math.abs(data.cost)
	return true
end

return CheckCommon
