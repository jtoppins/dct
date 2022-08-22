--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Initializes player slots.
--]]

local class    = require("libs.namedclass")
local enum     = require("dct.enum")
local dctutils = require("dct.libs.utils")
local STM      = require("dct.templates.STM")
local Template = require("dct.templates.Template")
local Logger   = dct.Logger.getByName("Systems")

local function isPlayerGroup(grp, _, _)
	local isplayer, slotcnt = dctutils.isplayergroup(grp)

	if isplayer and slotcnt > 1 then
		Logger:warn(string.format("DCT requires 1 slot groups. Group "..
			"'%s' of type a/c (%s) has more than one player slot.",
			grp.name, grp.units[1].type))
	end
	return isplayer
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
				["location"]  = { ["x"] = grp.data.x, ["y"] = grp.data.y, },
				["tpldata"]   = { [1] = grp, },
			}))
			theater:getAssetMgr():add(asset)
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("loadPlayerSlots(); found %d slots", cnt))
end

return PlayerSlots
