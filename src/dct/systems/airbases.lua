-- SPDX-License-Identifier: LGPL-3.0

--- Silence all airbase ATC towers. Only Airbases participating in the
-- campaign should have functioning ATC towers. Also, disable the
-- auto-capture feature so DCT can manage airbase ownership itself.

local settings = dct.settings.general or {}
local Airbases = require("libs.namedclass")("Airbases")
function Airbases:__init()
	for _, ab in pairs(world.getAirbases()) do
		if not settings.airbase_nosilence then
			ab:setRadioSilentMode(true)
		end

		-- disable auto-capture feature for all airbases
		-- on the map and set to neutral. DCT airbase objects
		-- will set the DCS airbase to the correct side later.
		if ab:getDesc().category ~= Airbase.Category.SHIP then
			ab:autoCapture(false)
			ab:setCoalition(coalition.side.NEUTRAL)
		end
	end
end

return Airbases
