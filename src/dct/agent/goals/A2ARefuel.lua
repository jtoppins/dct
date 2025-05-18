-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local IAUS  = libs.IAUS
local WS = require("dct.agent.worldstate")

--- A2ARefuel goal.
-- @classmod A2ARefuel

local function low_fuel(agent)
	local bingofact = agent:getFact(WS.Facts.factKey.BINGO)
	local fuelfact = agent:getFact(WS.Facts.factKey.FUEL)
	local typename = next(agent:getDescKey("unitTypeCnt"))
	local acdesc = Unit.getDescByName(typename)
	local maxfuel = acdesc.fuelMassMax
	local refuel = agent:getDescKey("refuelpct")
	local bingo

	if bingofact ~= nil then
		bingo = bingofact.value.value * maxfuel
	else
		bingo = agent:getDescKey("reservefuel") * 1.2
	end

	if refuel == nil then
		refuel = (bingo * 1.5) / maxfuel
	end

	local x = libs.utils.clamp(fuelfact.value.value, bingo/maxfuel, refuel)
	x = (refuel - x) / (refuel - (bingo / maxfuel))
	return x
end

local iaus = IAUS.IAUS(IAUS.Axis(low_fuel,
				 IAUS.curveTypes.LINEAR,
				 1, 0.5, 0, 0))

local A2ARefuel = class("A2ARefuel", WS.Goal)
function A2ARefuel:__init(node)
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.INAIR, true),
			WS.Property(WS.ID.ATNODE, node),
			WS.Property(WS.ID.STANCE, WS.Stance.REFUELING),
		}), 0.9, iaus)
end

return A2ARefuel
