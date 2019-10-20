--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a DCS Observer interface
--]]

local class      = require("libs.class")
local Observable = require("dct.observable")

local dcsobserver = nil
local DCSObserver = class(Observable)

function DCSObserver.getDCSObserver()
	if dcsobserver == nil then
		dcsobserver = DCSObserver()
	end
	return dcsobserver
end

function DCSObserver:__init()
	Observable.__init(self)
	world.addEventHandler(self)
end

return DCSObserver
