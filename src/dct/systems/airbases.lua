-- SPDX-License-Identifier: LGPL-3.0

--- Silence all airbase ATC towers. Only Airbases participating in the
-- campaign should have functioning ATC towers.

-- TODO: add the theater settings
local settings = dct.settings.airbases or {}
local Airbases = require("libs.namedclass")("Airbases")
function Airbases:__init()
	local silenceneutrals = settings.neutrals or false

	for _, ab in pairs(world.getAirbases()) do
		if ab:getCoalition() == coalition.side.NEUTRAL then
			ab:setRadioSilentMode(silenceneutrals)
		elseif settings.nosilence then
			ab:setRadioSilentMode(true)
		end
	end
end

return Airbases
