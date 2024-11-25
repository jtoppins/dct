-- SPDX-License-Identifier: LGPL-3.0

--- AmmoCount. Provide a common way of totaling a unit/group's
-- weapons they have available.
-- @classmod dct.libs.AmmoCount

require("libs")

local class = libs.classnamed
local dctutils = require("dct.libs.utils")

--- Defines which weapon categories are classified as anti-air missiles.
local isAAMissile = {
	[Weapon.MissileCategory.AAM] = true,
	[Weapon.MissileCategory.SAM] = true,
}

--- A container object that contains weapon totals for a Unit or
-- Group categorized into three general categories.
-- @type AmmoCount
local AmmoCount = class("AmmoCount")

--- Infinite weapon cost.
AmmoCount.WPNINFCOST = 5000

--- The weapon categories each weapon is grouped into.
AmmoCount.weaponCategory = {
	["AA"] = 1,  -- all anti-air weapons.
	["AG"] = 2,  -- all anti-ground weapons (can be Air-to-Surface
		     --    or Surface-to-Surface.
	["GUN"] = 3, -- all projectile ammo
}

--- Constructor.
-- @tparam table limits a limits table specifying the maximum points
--   allowed per AmmoCount.weaponCategory.
-- @tparam table costs [optional] the weapon costs table to use when
--   totaling a payload. The table keys are weapon type strings and
--   values are numbers.
-- @tparam number defcost [optional] default cost to use if no cost is
--   listed in the costs table; default: 0
function AmmoCount:__init(limits, costs, defcost)
	limits = limits or {}
	self._wpncosts = costs or {}
	self._defcost = defcost or 0
	self.totals = {}
	for _, v in pairs(AmmoCount.weaponCategory) do
		self.totals[v] = {
			["current"] = 0,
			["max"]     = limits[v] or AmmoCount.WPNINFCOST,
			["payload"] = {}
		}
	end

	self.weaponCategory = nil
	self.WPNINFCOST = nil
end

--- Categorize the weapon into one of the three groups.
function AmmoCount:categorize(weapon)
	if weapon.desc.category == Weapon.Category.SHELL then
		return AmmoCount.weaponCategory.GUN
	elseif isAAMissile[weapon.desc.missileCategory] then
		return AmmoCount.weaponCategory.AA
	end
	return AmmoCount.weaponCategory.AG
end

--- Add all weapon types for a given unit.
-- @param unit dcs unit reference
function AmmoCount:add(unit)
	local payload = unit:getAmmo()

	-- total weapon costs
	for _, wpn in ipairs(payload or {}) do
		local wpnname = dctutils.trimTypeName(wpn.desc.typeName)
		local wpncnt  = wpn.count
		local category = self:categorize(wpn)
		local cost = self._wpncosts[wpnname] or self._defcost

		self.totals[category].current =
			self.totals[category].current + (wpncnt * cost)

		table.insert(self[category].payload, {
			["name"]  = wpn.desc.displayName,
			["type"]  = wpnname,
			["count"] = wpncnt,
			["cost"]  = cost,
		})
	end
end

--- Verifies if the current total is less than limit cost for each weapon
-- category.
function AmmoCount:isValid()
	for _, cost in pairs(self.totals) do
		if cost.current > cost.max then
			return false
		end
	end
	return true
end

return AmmoCount
