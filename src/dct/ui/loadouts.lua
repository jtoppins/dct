-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a loadout point buy system to limit player loadouts.
-- Assumes a single player slot per group and it is the first slot.

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")

local isAAMissile = {
	[Weapon.MissileCategory.AAM] = true,
	[Weapon.MissileCategory.SAM] = true,
}

local function default_category(weapon)
	if weapon.desc.category == Weapon.Category.SHELL then
		return dctenum.weaponCategory.GUN
	elseif isAAMissile[weapon.desc.missileCategory] then
		return dctenum.weaponCategory.AA
	end
	return dctenum.weaponCategory.AG
end

local function init_totals(limits)
	local total = {}

	for _, v in pairs(dctenum.weaponCategory) do
		total[v] = {
			["current"] = 0,
			["max"]     = limits[v] or 0,
			["payload"] = {}
		}
	end

	return total
end

--- tally all weapon types for a given unit
--
-- @param unit dcs unit reference
-- @param limits the limits table to use
-- @param restrictions the restrictions table to use
-- @param defcost the default cost of a weapon
-- @return a total table keyed on weapon category
local function total_payload(unit, limits, restrictions, defcost)
	local payload = unit:getAmmo()
	local total = init_totals(limits)
	restrictions = restrictions or {}
	defcost = defcost or 0

	-- tally weapon costs
	for _, wpn in ipairs(payload or {}) do
		local wpnname = dctutils.trimTypeName(wpn.desc.typeName)
		local wpncnt  = wpn.count
		local restriction = restrictions[wpnname] or {}
		local category = restriction.category or default_category(wpn)
		local cost = restriction.cost or defcost

		if category ~= nil then
			total[category].current =
				total[category].current + (wpncnt * cost)

			table.insert(total[category].payload, {
				["name"]  = wpn.desc.displayName,
				["type"]  = wpnname,
				["count"] = wpncnt,
				["cost"]  = cost,
			})
		end
	end
	return total
end

-- returns a two tuple;
--   first arg (boolean) is payload valid
--   second arg (table) total cost per category of the payload, also
--       includes the max allowed for the airframe
local function validate_payload(unit, limits)
	local total = total_payload(unit, limits)

	for _, cost in pairs(total) do
		if cost.current > cost.max then
			return false, total
		end
	end

	return true, total
end

-- print cost summary
local function build_summary(costs)
	local msg = "== Loadout Summary:"

	for desc, cat in pairs(dctenum.weaponCategory) do
		if costs[cat].current < dctenum.WPNINFCOST then
			msg = msg..string.format("\n  %s cost: %.4g / %d",
						 desc, costs[cat].current,
						 costs[cat].max)
		else
			msg = msg..string.format("\n  %s cost: -- / %d",
						 desc, costs[cat].max)
		end
	end
	return msg
end

local function build_payload_details(payload, desc)
	if next(payload) == nil then
		return ""
	end

	local msg = string.format("\n\n== %s Weapons:", desc)

	for _, wpn in pairs(payload) do
		msg = msg..string.format("\n  %s\n    ↳ ", wpn.name)
		if wpn.cost == 0 then
			msg = msg..string.format("%d × unrestricted (0 pts)",
						 wpn.count)
		elseif wpn.cost < dctenum.WPNINFCOST then
			msg = msg..string.format("%d × %.4g pts = %.4g pts",
				wpn.count, wpn.cost, wpn.count * wpn.cost)
		else
			msg = msg.."Weapon cannot be used in this theater [!]"
		end
	end
	return msg
end

local loadout = {}

--- Generate a payload summary for the costs table provided
--
-- @return text string summary of the loadout
function loadout.summary(costs)
	local msg = build_summary(costs)

	-- group weapons by category
	for desc, cat in pairs(dctenum.weaponCategory) do
		msg = msg..build_payload_details(costs[cat].payload, desc)
	end

	return msg
end

loadout.total = total_payload

function loadout.check(player)
	return validate_payload(Group.getByName(player.name):getUnit(1),
				player:getDescKey("payloadlimits"))
end

function loadout.addmenu(gid, name, menu, handler)
	return missionCommands.addCommandForGroup(gid,
		"Check Payload", menu, handler, {
			["name"]   = name,
			["type"]   = dctenum.uiRequestType.CHECKPAYLOAD,
		})
end

return loadout
