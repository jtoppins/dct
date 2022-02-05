--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

local utils = require("libs.utils")
local class = require("libs.class")

local DCTEvents = class()
function DCTEvents:__init()
	self._eventhandlers = {}
end

function DCTEvents:_overridehandlers(handlers)
	self._eventhandlers = utils.mergetables(self._eventhandlers, handlers)
end

--- Process a DCS or DCT event.
-- @returns none
function DCTEvents:onDCTEvent(event)
	local handler = self._eventhandlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

return DCTEvents
