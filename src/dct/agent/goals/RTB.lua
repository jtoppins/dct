-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local IAUS = libs.IAUS
local WS = require("dct.agent.worldstate")

--- Return To Base (RTB) goal. Once a group hits bingo fuel this
-- goal should be the most desirable goal. The goal is weighted
-- heavier than all other goals.
-- @classmod RTB

--- Once bingo fuel is reached return 1. If we have more than
-- 40% above bingo return 0.
local function bingo_fuel(agent)
	local bingofact = agent:getFact(WS.Facts.factKey.BINGO)
	local fuelfact = agent:getFact(WS.Facts.factKey.FUEL)
	local typename = next(agent:getDescKey("unitTypeCnt"))
	local acdesc = Unit.getDescByName(typename)
	local maxfuel = acdesc.fuelMassMax
	local bingo

	if bingofact ~= nil then
		bingo = bingofact.value.value * maxfuel
	else
		bingo = agent:getDescKey("reservefuel") * 1.2
	end

	local min = (bingo * 1.0) / maxfuel
	local max = (bingo * 1.4) / maxfuel
	local x = libs.utils.clamp(fuelfact.value.value, min, max)

	x = (max - x) / (max - min)
	return x
end

local iaus = IAUS.IAUS(IAUS.Axis(bingo_fuel,
				 IAUS.curveTypes.LINEAR,
				 1, 2, 0.05, 0))

local RTB = class("RTB", WS.Goal)
function RTB:__init()
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.INAIR, false),
			WS.Property(WS.ID.ATNODETYPE,
				    WS.Facts.Node.nodeType.HOMEBASE),
		}), 1, iaus)
end

function RTB.isSuitable(agent)
	local is_bit_set = dct.libs.utils.is_bit_set
	local assetType = dct.enum.assetType

	return is_bit_set(assetType.AIR_UNIT, agent.type)
end

return RTB
