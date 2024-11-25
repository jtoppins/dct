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

local function scratchpad_get(agent)
	if not dctutils.isalive(agent.name) then
		return
	end

	local fact = agent:getFact(WS.Facts.factKey.SCRATCHPAD)
	local msg = "Scratch Pad: "

	if fact then
		msg = msg .. tostring(fact.value.value)
	else
		msg = msg .. "nil"
	end
	post_msg(agent, "scratchpad_msg", msg)
end

local function scratchpad_set(agent)
	local theater = dct.Theater.singleton()
	local gid = agent:getDescKey("groupId")
	local pos = Group.getByName(agent.name):getUnit(1):getPoint()
	local scratchpad = theater:getSystem("dct.systems.scratchpad")
	local mark = uidraw.Mark("edit me", pos, false,
				 uidraw.Mark.scopeType.GROUP, gid)

	scratchpad:set(mark.id, {
		["name"] = agent.name,
		["mark"] = mark,
	})
	mark:draw()
	local msg = "Look on F10 MAP for user mark with contents \""..
		"edit me\"\n Edit body with your scratchpad "..
		"information. Click off the mark when finished. "..
		"The mark will automatically be deleted."
	post_msg(agent, "scratchpad_msg", msg)
end

--- Manage Scratch Pad menu items
-- F1: Scratch Pad
--   F1: Display
--   F2: Set
local function create_scratchpad(menu)
	menu:addRqstCmd("Display", uirequest.scratchpad_get)
	menu:addRqstCmd("Set", uirequest.scratchpad_set)
end

return ScratchPad
