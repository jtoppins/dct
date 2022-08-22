--- SPDX-License-Identifier: LGPL-3.0

local utils = require("libs.utils")
local class = require("libs.namedclass")
local Check = require("dct.templates.checkers.Check")
local ckey  = "coalition"

local function testCoalition(tpl, grp)
	if grp.countryid == nil then
		return true
	end

	local groupCoalition = coalition.getCountryCoalition(grp.countryid)

	tpl.coalition = tpl.coalition or groupCoalition
	if tpl.coalition ~= groupCoalition then
		return false, ckey, string.format("template contains mixed "..
		"coalitions; one group belongs to country '%s', which is "..
		"in the '%s' coalition, but another group in the template "..
		"is in the '%s' coalition\nnote: coalition checks are made "..
		"according to the .miz, not the .stm\nnote: if this is "..
		"intentional, consider setting the coalition manually in "..
		"the .dct",
		country.name[grp.countryid],
		utils.getkey(coalition.side, groupCoalition),
		utils.getkey(coalition.side, tpl.coalition))
	end
	return true
end

local function verifySingleCoalition(data)
	for _, grp in pairs(data.tpldata) do
		local ok, key, msg = testCoalition(data, grp)
		if not ok then
			return ok, key, msg
		end
	end
	return true
end

local CheckCoalition = class("CheckCoalition", Check)
function CheckCoalition:__init()
	Check.__init(self, "Common", {
		[ckey] = {
			["type"] = Check.valuetype.VALUES,
			["values"] = coalition.side,
			["description"] =
			"",
		},
	})
end

function CheckCoalition:check(data)
	if data.coalition ~= nil then
		return Check.check(self, data)
	end

	local ok, key, msg = verifySingleCoalition(data)
	if not ok then
		return ok, key, msg
	end

	if data.coalition == nil then
		return false, ckey, "cannot determine the coalition "..
		       "of template because it has no units; please set "..
		       "it manually in the .dct"
	end
	return true
end

return CheckCoalition
