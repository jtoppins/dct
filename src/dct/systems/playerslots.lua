-- SPDX-License-Identifier: LGPL-3.0
--
-- Initializes player slots.

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctutils = require("dct.libs.utils")
local STM      = require("dct.templates.STM")
local Template = require("dct.templates.Template")
local Region   = require("dct.templates.Region")
local Logger   = dct.Logger.getByName("Systems")

local function is_player_group(grp, _, _)
	local isplayer, slotcnt = dctutils.isplayergroup(grp)

	if isplayer and slotcnt > 1 then
		Logger:warn("DCT requires 1 slot groups. Group '%s' of "..
			    "type a/c (%s) has more than one player slot.",
			    grp.name, grp.units[1].type)
	end
	return isplayer
end

local PlayerSlots = class("PlayerSlots")
function PlayerSlots:postinit()
	local cnt = 0
	local theater = dct.Theater.singleton()
	local assetmgr = theater:getAssetMgr()
	local region = Region({
		["name"] = "__builtin",
		["priority"] = 1000,
		["builtin"] = true,
	})

	theater:getRegionMgr():addRegion(region)
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
						  env.getValueDictByKey,
						  is_player_group,
						  nil)
		for _, grp in ipairs(grps) do
			local side = coalition.getCountryCoalition(grp.countryid)
			local tpl = Template({
				["objtype"]   = "player",
				["name"]      = grp.data.name,
				["coalition"] = utils.getkey(coalition.side,
							     side),
				["cost"]      = theater:getTickets():
						getPlayerCost(side),
				["desc"]      = "Player group",
				["location"]  = { ["x"] = grp.data.x,
						  ["y"] = grp.data.y, },
				["tpldata"]   = { [1] = grp, },
			})

			region:addTemplate(tpl)
			assetmgr:add(tpl:createObject())
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("PlayerSlots:__init(); found %d slots", cnt))
end

return PlayerSlots
