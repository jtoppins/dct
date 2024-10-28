-- SPDX-License-Identifier: LGPL-3.0

require("libs")

local utils = libs.utils
local class = libs.class

--- DCTEvents class. Provides a common way for objects to process events.
-- @classmod dct.libs.DCTEvents
local DCTEvents = class()

--- Class constructor.
function DCTEvents:__init()
	self._eventhandlers = {}
end

--- [internal] Overrides event handlers in the object.
-- Used mainly internally in inhertining constructor functions.
function DCTEvents:_overridehandlers(handlers)
	self._eventhandlers = utils.mergetables(self._eventhandlers, handlers)
end

--- Process a DCS or DCT event.
-- @param event the event object to dispatch
-- @return none
function DCTEvents:onDCTEvent(event)
	local handler = self._eventhandlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

return DCTEvents
