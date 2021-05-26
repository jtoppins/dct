--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Initializes player slots.
--]]

local class    = require("libs.namedclass")
local enum     = require("dct.enum")
local STM      = require("dct.templates.STM")
local Template = require("dct.templates.Template")
local Logger   = dct.Logger.getByName("Systems")

local function isPlayerGroup(grp, _, _)
	local slotcnt = 0
	for _, unit in ipairs(grp.units) do
		if unit.skill == "Client" then
			slotcnt = slotcnt + 1
		end
	end
	if slotcnt > 0 then
		if slotcnt > 1 then
			Logger:warn(string.format("DCT requires 1 slot groups. Group "..
				"'%s' of type a/c (%s) has more than one player slot.",
				grp.name, grp.units[1].type))
		end
		return true
	end
	return false
end

local PlayerSlots = class("PlayerSlots")
function PlayerSlots:__init(theater)
	local cnt = 0
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
			env.getValueDictByKey,
			isPlayerGroup,
			nil)
		for _, grp in ipairs(grps) do
			local side = coalition.getCountryCoalition(grp.countryid)
			local asset =
			theater:getAssetMgr():factory(enum.assetType.PLAYERGROUP)(Template({
				["objtype"]   = "playergroup",
				["name"]      = grp.data.name,
				["regionname"]= "theater",
				["regionprio"]= 1000,
				["coalition"] = side,
				["cost"]      = theater:getTickets():getPlayerCost(side),
				["desc"]      = "Player group",
				["tpldata"]   = grp,
			}))
			theater:getAssetMgr():add(asset)
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("loadPlayerSlots(); found %d slots", cnt))
end

return PlayerSlots
