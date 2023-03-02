--- SPDX-License-Identifier: LGPL-3.0

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
