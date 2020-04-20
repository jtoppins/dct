--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles raw player input via a "scratchpad" system. The
-- addition of the F10 menu is handled outside this module.
--]]

local Logger  = require("dct.Logger").getByName("UI")

local function sanatize(txt)
	if type(txt) ~= "string" then
		return nil
	end
	-- only allow: alphanumeric characters, period, hyphen, underscore,
	-- colon, and space
	return txt:gsub('[^%w%.%-_: ]', '')
end

local function uiScratchPad(theater, event)
	if event.id ~= world.event.S_EVENT_MARK_CHANGE then
		return
	end

	local name = theater.scratchpad[event.idx]
	if name == nil then
		return
	end

	local playerasset = theater:getAssetMgr():getAsset(name)
	playerasset.scratchpad = sanatize(event.text)
	theater.scratchpad[event.idx] = nil
	trigger.action.removeMark(event.idx)
end

local function init(theater)
	assert(theater ~= nil, "value error: theater must be a non-nil value")
	Logger:debug("init Scratchpad event handler")
	theater:registerHandler(uiScratchPad, theater)
end

return init
