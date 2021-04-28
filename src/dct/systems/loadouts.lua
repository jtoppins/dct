--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a loadout point buy system to limit player loadouts.
-- Assumes a single player slot per group and it is the first slot.
--]]

require("lfs")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local settings = _G.dct.settings

-- returns totals for all weapon types, returns nil if the group
-- does not exist
local function totalPayload(grp, limits)
	local unit = grp:getUnit(1)
	local restrictedWeapons = settings.restrictedweapons
	local payload = unit:getAmmo()
	local total = {}
	for _, v in pairs(enum.weaponCategory) do
		total[v] = {
			["current"] = 0,
			["max"]     = limits[v],
		}
	end

	-- tally restricted weapon cost
	for _, wpn in ipairs(payload or {}) do
		local wpnname = dctutils.trimTypeName(wpn.desc.typeName)
		local wpncnt  = wpn.count
		local restricted = restrictedWeapons[wpnname]

		if restricted then
			total[restricted.category].current =
				total[restricted.category].current +
				(wpncnt * restricted.cost)
		end
	end
	return total
end

-- returns a two tuple;
--   first arg (boolean) is payload valid
--   second arg (table) total cost per category of the payload, also
--       includes the max allowed for the airframe
local function validatePayload(grp, limits)
	local total = totalPayload(grp, limits)

	for _, cost in pairs(total) do
		if cost.current > cost.max then
			return false, total
		end
	end

	return true, total
end

local loadout = {}

function loadout.check(player)
	return validatePayload(Group.getByName(player.name),
		player.payloadlimits)
end

function loadout.addmenu(asset, menu, handler)
	local gid  = asset.groupId
	local name = asset.name
	return missionCommands.addCommandForGroup(gid,
		"Check Payload", menu, handler, {
			["name"]   = name,
			["type"]   = enum.uiRequestType.CHECKPAYLOAD,
		})
end

return loadout
