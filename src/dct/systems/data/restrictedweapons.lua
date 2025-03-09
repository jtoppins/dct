-- SPDX-License-Identifier: LGPL-3.0

--- Default restricted weapons.
local AmmoCount = require("dct.libs.AmmoCount")

return {
	["RN-24"] = {
		["cost"]     = AmmoCount.WPNINFCOST,
		["category"] = AmmoCount.weaponCategory.AG,
	},
	["RN-28"] = {
		["cost"]     = AmmoCount.WPNINFCOST,
		["category"] = AmmoCount.weaponCategory.AG,
	},
}
