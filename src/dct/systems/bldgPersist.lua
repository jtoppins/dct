--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a basic building persisntence system.
--]]

local class  = require("libs.namedclass")
local Marshallable = require("dct.libs.Marshallable")
local Logger = require("dct.libs.Logger").getByName("System")

local SceneryTracker = class("SceneryTracker", Marshallable)
function SceneryTracker:__init(theater)
	Marshallable.__init(self)
	self.destroyed = {}
	theater:addObserver(self.onDCSEvent, self,
		self.__clsname..".onDCSEvent")
	self:_addMarshalNames({
		"destroyed",
	})
end

function SceneryTracker:_unmarshalpost()
	for _, bldg in pairs(self.destroyed) do
		local id = tonumber(bldg)
		local obj = {id_ = id}
		local pt = Object.getPoint(obj)
		trigger.action.explosion(pt, 500)
	end
end

function SceneryTracker:onDCSEvent(event)
	if event.id ~= world.event.S_EVENT_DEAD then
		Logger:debug(string.format("onDCSEvent() -"..
		" bldgPersist not DEAD event, ignoring"))
		return
	end
	local obj = event.initiator
	if obj:getCategory() == Object.Category.SCENERY then
		table.insert(self.destroyed, tostring(obj:getName()))
	end
end

return SceneryTracker
