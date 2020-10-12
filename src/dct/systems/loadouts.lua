--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a loadout point buy system to limit player loadouts.
-- Assumes a single player slot per group and it is the first slot.
--]]

require("lfs")
local enum     = require("dct.enum")
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
local function validatePayload(grp, limits)
	local total = totalPayload(grp, limits)

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

function loadout.kick(grp, limits)
	local ok = validatePayload(grp, limits)
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

function loadout.check(grp, limits)
	local msg
	local ok, costs = validatePayload(grp, limits)
	if ok then
		msg = "Valid loadout, you may depart. Good luck!"
	else
		msg = "You are over budget! Re-arm before departing, or "..
			"you will be kicked to spectator!"
	end

	-- print cost summary
	msg = msg.."\n== Loadout Summary:"
	for cat, val in pairs(enum.weaponCategory) do
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
