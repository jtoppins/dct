--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a loadout point buy system to limit player loadouts.
-- Assumes a single player slot per group and it is the first slot.
--]]

local enum = require("dct.enum")

local weaponCategory = {
	["AA"]     = 0,
	["AG"]     = 1,
}

local infcost = 5000

-- Define Values for all Limited Ordnance --
local restrictedWeapons = {
	["AIM-120C"] = {
		["cost"]     = 3,
		["category"] = weaponCategory.AA,
	},
	["AIM-120B"] = {
		["cost"]     = 3,
		["category"] = weaponCategory.AA,
	},
	["AIM_54A_Mk47"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AA,
	},
	["AIM_54A_Mk60"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AA,
	},
	["AIM_54C_Mk47"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AA,
	},
	["SD-10"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AA,
	},
	["R-77"] = {
		["cost"]     = 3,
		["category"] = weaponCategory.AA,
	},
	["GBU-10"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AA,
	},
	["GBU-12"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["GBU-16"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["GBU-24"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["GBU-38"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["GBU-31"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["GBU-31(V)3/B"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["AGM-62"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["GB-6"] = {
		["cost"]     = 25,
		["category"] = weaponCategory.AG,
	},
	["GB-6-HE"] = {
		["cost"]     = 25,
		["category"] = weaponCategory.AG,
	},
	["GB-6-SFW"] = {
		["cost"]     = 30,
		["category"] = weaponCategory.AG,
	},
	["LS-6-500"] = {
		["cost"]     = 25,
		["category"] = weaponCategory.AG,
	},
	["CM-802AKG"] = {
		["cost"]     = 30,
		["category"] = weaponCategory.AG,
	},
	["C-802AK"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["AGM-88C"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-84D"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["LD-10"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-154A"] = {
		["cost"]     = 25,
		["category"] = weaponCategory.AG,
	},
	["AGM-154C"] = {
		["cost"]     = 25,
		["category"] = weaponCategory.AG,
	},
	["AGM-65E"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-65F"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-65D"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-65G"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-65H"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["AGM-65K"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["C-701T"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["C-701IR"] = {
		["cost"]     = 10,
		["category"] = weaponCategory.AG,
	},
	["CBU-87"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["CBU-97"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["CBU-99"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["CBU-103"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["CBU-105"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["CBU-107"] = {
		["cost"]     = 15,
		["category"] = weaponCategory.AG,
	},
	["CBU-109"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["Mk-20"] = {
		["cost"]     = 5,
		["category"] = weaponCategory.AG,
	},
	["RN-24"] = {
		["cost"]     = infcost,
		["category"] = weaponCategory.AG,
	},
	["RN-28"] = {
		["cost"]     = infcost,
		["category"] = weaponCategory.AG,
	},
	["AGM-84E SLAM"] = {
		["cost"]     = 30,
		["category"] = weaponCategory.AG,
	},
}

-- Define Maximum Allowed Values for all Airframes --
local restrictedAirframes = {
	["DEFAULT"] = {
		[weaponCategory.AA] = 20,
		[weaponCategory.AG] = 60,
	},
	["A-10C"] = {
		[weaponCategory.AA] = 20,
		[weaponCategory.AG] = 80,
	},
}

-- returns totals for all weapon types, returns nil if the group
-- does not exist
local function totalPayload(grp)
	local unit = grp:getUnit(1)
	local limits = restrictedAirframes[unit:getTypeName()]
	if not limits then
		limits = restrictedAirframes.DEFAULT
	end
	local payload = unit:getAmmo()
	local total = {}
	for _, v in pairs(weaponCategory) do
		total[v] = {
			["current"] = 0,
			["max"]     = limits[v],
		}
	end

	-- tally restricted weapon cost
	for _, wpn in ipairs(payload) do
		local wpnname = wpn.desc.displayName
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
local function validatePayload(grp)
	local total = totalPayload(grp)

	for _, cost in pairs(total) do
		if cost.current > cost.max then
			return false, total
		end
	end

	return true, total
end

local notifymsg =
	"Please read the loadout limits in the briefing and "..
	"use the F10 Menu to validate your loadout before departing."
local loadout = {}

function loadout.notify(grp)
	trigger.action.outTextForGroup(grp:getID(), notifymsg, 20, false)
end

function loadout.kick(grp)
	local ok = validatePayload(grp)
	if ok then
		return
	end

	trigger.action.outTextForGroup(grp:getID(),
		"You have been removed to spectator for flying with an "..
		"invalid loadout. "..notifymsg,
		20, true)
	trigger.action.setUserFlag(grp:getName(), 100)
	return ok
end

function loadout.check(grp)
	local msg
	local ok, costs = validatePayload(grp)
	if ok then
		msg = "Valid loadout, you may depart. Good luck!"
	else
		msg = "You are over budget! Re-arm before departing, or "..
			"you will be kicked to spectator!"
	end

	-- print cost summary
	msg = msg.."\n== Loadout Summary:"
	for cat, val in pairs(weaponCategory) do
		msg = msg ..string.format("\n\t%s cost: %d / %d",
			cat, costs[val].current, costs[val].max)
	end
	return msg
end

function loadout.addmenu(asset, menu, handler, context)
	local gid  = asset.groupId
	local name = asset.name
	missionCommands.addCommandForGroup(gid,
		"Check Payload", menu, handler, context, {
			["name"]   = name,
			["type"]   = enum.uiRequestType.CHECKPAYLOAD,
		})
end

return loadout
