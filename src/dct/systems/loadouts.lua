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

local isAAMissile = {
	[Weapon.MissileCategory.AAM] = true,
	[Weapon.MissileCategory.SAM] = true,
}

local function defaultCategory(weapon)
	if isAAMissile[weapon.desc.missileCategory] then
		return enum.weaponCategory.AA
	elseif weapon.desc.category ~= Weapon.Category.SHELL then
		return enum.weaponCategory.AG
	end
end

-- returns totals for all weapon types, or nil if the group does not exist
local function totalPayload(grp, limits)
	local unit = grp:getUnit(1)
	local restrictedWeapons = settings.restrictedweapons
	local payload = unit:getAmmo()
	local total = {}
	for _, v in pairs(enum.weaponCategory) do
		total[v] = {
			["current"] = 0,
			["max"]     = limits[v] or 0,
			["payload"] = {}
		}
	end

	-- tally weapon costs
	for _, wpn in ipairs(payload or {}) do
		local wpnname = dctutils.trimTypeName(wpn.desc.typeName)
		local wpncnt  = wpn.count
		local restriction = restrictedWeapons[wpnname] or {}
		local category = restriction.category or defaultCategory(wpn)
		local cost = restriction.cost or 0

		if category ~= nil then
			total[category].current =
				total[category].current + (wpncnt * cost)

			table.insert(total[category].payload, {
				["name"] = wpn.desc.displayName,
				["count"] = wpncnt,
				["cost"] = cost,
			})
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
