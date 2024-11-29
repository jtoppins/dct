-- SPDX-License-Identifier: LGPL-3.0

--- Silence all airbase ATC towers. Only Airbases participating in the
-- campaign should have functioning ATC towers. Also, disable the
-- auto-capture feature so DCT can manage airbase ownership itself.

require("libs")
local class = libs.classnamed
local System = require("dct.libs.System")

local Airbases = class("Airbases", System)

Airbases.enabled = true
Airbases.settings = {}

--- This setting will determine if the ATC tower is disabled by default
-- until a DCT airbase object takes ownership. By default all airbases
-- are silenced unless DCT is controlling the airbase. Set to true to
-- keep DCS's ATC system on for all airbases, including ships.
Airbases.settings.nosilence = false

--- Control if DCS's base autocapture feature is enabled. By default
-- the game has this enabled so by default DCT turns it off to prevent
-- some odd behaviour. DCT airbase objects will set the DCS airbase to
-- the correct side later.
Airbases.settings.autocapture = false

function Airbases:__init(theater)
	System.__init(self, theater, System.PRIORITY.ADDON)
end

function Airbases:initialize()
	for _, ab in pairs(world.getAirbases()) do
		if not self.settings.nosilence then
			ab:setRadioSilentMode(true)
		end

		if ab:getDesc().category ~= Airbase.Category.SHIP then
			ab:autoCapture(self.settings.autocapture)

			if not self.settings.autocapture then
				ab:setCoalition(coalition.side.NEUTRAL)
			end
		end
	end
end

return Airbases

--[[ TODO
local airbase_id2name_map = false
function utils.airbase_id2name(id)
	if id == nil then
		return nil
	end

	if airbase_id2name_map == false then
		airbase_id2name_map = {}
		for _, ab in pairs(world.getAirbases()) do
			airbase_id2name_map[tonumber(ab:getID())] =
				ab:getName()
		end
	end
	return airbase_id2name_map[id]
end
--]]
