--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local vector   = require("dct.libs.vector")
local Check    = require("dct.templates.checkers.Check")

local function calclocation(tpl)
	local vec2, n

	for _, grp in pairs(tpl.tpldata) do
		vec2, n = dctutils.centroid2D(grp.data, vec2, n)
	end

	vec2.z = nil

	return vec2
end

local CheckLocation = class("CheckLocation", Check)
function CheckLocation:__init()
	Check.__init(self, "Location")
end

function CheckLocation:check(data)
	local loc = data.location

	if loc == nil or next(loc) == nil then
		if data.objtype == dctenum.assetType.AIRBASE or
		   data.objtype == dctenum.assetType.SQUADRONPLAYER then
			return true
		end

		if data.tpldata == nil or next(data.tpldata) == nil then
			return false, "location",
			       "no location and no DCS units defined"
		end

		loc = calclocation(data)
	end

	for _, val in pairs({"x", "y"}) do
		if loc[val] == nil or type(loc[val]) ~= "number" then
			return false, "location",
			       "location defined in template is invalid"
		end
	end

	local vec2 = vector.Vector2D(loc)
	data.location = vector.Vector3D(vec2,
					land.getHeight(vec2:raw())):raw()
	return true
end

return CheckLocation
