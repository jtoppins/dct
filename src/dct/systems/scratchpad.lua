-- SPDX-License-Identifier: LGPL-3.0

--- Handles raw player input via a "scratchpad" system. The
-- addition of the F10 menu is handled outside this module.
-- @module dct.systems.scratchpad

require("libs")
local class  = libs.classnamed
local WS     = require("dct.agent.worldstate")

local function sanatize(txt)
	if type(txt) ~= "string" then
		return nil
	end
	-- only allow: alphanumeric characters, period, hyphen, underscore,
	-- colon, and space
	return txt:gsub('[^%w%.%-_: ]', '')
end

local ScratchPad = class("ScratchPad")
function ScratchPad:__init(theater)
	self._scratchpad = {}
	self._theater = theater
	theater:addObserver(self.event, self, self.__clsname)
end

function ScratchPad:get(id)
	return self._scratchpad[id]
end

function ScratchPad:set(id, data)
	self._scratchpad[id] = data
end

function ScratchPad:event(event)
	if event.id ~= world.event.S_EVENT_MARK_CHANGE then
		return
	end

	local data = self:get(event.idx)
	if data == nil then
		return
	end

	local player = self._theater:getAssetMgr():getAsset(data.name)
	player:setFact(WS.Facts.factKey.SCRATCHPAD,
		       WS.Facts.Value(WS.Facts.factType.SCRATCHPAD,
				      sanatize(event.text)))
	self:set(event.idx, nil)
	data.mark:remove()
end

return ScratchPad
