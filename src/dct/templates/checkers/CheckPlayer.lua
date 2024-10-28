-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class   = libs.classnamed
local dctenum = require("dct.enum")
local uihuman = require("dct.ui.human")
local Check   = require("dct.libs.Check")
local settings = dct.settings


--- Check player.
-- @classmod CheckPlayer
local CheckPlayer = class("CheckPlayer", Check)
function CheckPlayer:__init()
	Check.__init(self, "Player", {
		["groupId"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.INT,
			["description"] = "group ID of the player group",
		},
		["parking"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.INT,
			["description"] = "The parking id",
		},
		["squadron"] = {
			["nodoc"] = true,
			["agent"] = true,
			["default"] = false,
			["type"] = Check.valuetype.STRING,
			["description"] =
				"The squadron the slot is associated with",
		},
		["ato"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLE,
			["default"] = {},
		},
		["payloadlimits"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLE,
			["default"] = {} --TODO: settings.payloadlimits["default"],
		},
		["gridfmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.posfmt,
			["default"] = uihuman.posfmt.DMS,
		},
		["distfmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.distancefmt,
			["default"] = uihuman.distancefmt.NAUTICALMILE,
		},
		["altfmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.altfmt,
			["default"] = uihuman.altfmt.FEET,
		},
		["speedfmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.speedfmt,
			["default"] = uihuman.speedfmt.KNOTS,
		},
		["pressurefmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.pressurefmt,
			["default"] = uihuman.pressurefmt.INHG,
		},
		["tempfmt"] = {
			["nodoc"] = true,
			["agent"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = uihuman.tempfmt,
			["default"] = uihuman.tempfmt.F,
		},
	})
end

function CheckPlayer:check(data)
	if data.objtype ~= dctenum.assetType.PLAYER then
		return true
	end

	data.overwrite = false
	data.rename = false

	if next(data.tpldata) == nil then
		return true
	end

	local ok, msg = Check.check(self, data)
	if not ok then
		return ok, msg
	end

	local actype = data.tpldata[1]["data"].units[1].type
	local ui = settings.ui[actype]

	data.ato = settings.ato[actype] or data.ato
	data.payloadlimits = {}
	--[[ TODO
	settings.payloadlimits[actype] or
			     data.payloadlimits
			     --]]
	data.cost = settings.airframecost[actype] or data.cost

	if ui ~= nil then
		for k, v in pairs(ui) do
			data[k] = v
		end
	end

	return true
end

return CheckPlayer
