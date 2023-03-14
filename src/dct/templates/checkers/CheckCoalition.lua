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
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = coalition.side,
			["description"] = [[
A template can only belong to a single coalition (side). If not specified, it
will be detected based on units and objects present in the template, but if it
does not contain anything (ie. an airbase), or contains objects of multiple
coalitions, this value must be filled.

> Important: units and objects saved in templates belong to countries, but the
coalitions of those objects in-game will be set based on the settings of the
.miz file. For example, if you create a template where the USA is a Blue
country, and then run it in a .miz where the USA is set as a neutral country,
the units in the template will spawn as neutral. Therefore, mission designers
should standardize which countries belong to which coalition, so that the
coalitions in templates are consistent with in-game results.

%VALUES%]],
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
