--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a basic building persisntence system.
--]]

local class  = require("libs.namedclass")
local Marshallable = require("dct.libs.Marshallable")
local Logger = require("dct.libs.Logger").getByName("System")

local SceneryTracker = class("SceneryTracker", Marshallable)
function SceneryTracker:__init()
	Marshallable.__init(self)
	self.destroyed = {}
	self:_addMarshalNames({
		"destroyed",
	})
end

function SceneryTracker:postinit(theater)
	theater:addObserver(self.onDCSEvent, self,
		self.__clsname..".onDCSEvent")
end

function SceneryTracker:_unmarshalpost()
	for bldg, _ in pairs(self.destroyed) do
		local pt = Object.getPoint({id_ = tonumber(bldg)})
		trigger.action.explosion(pt, 250)
	end
end

function SceneryTracker:addObject(id)
	self.destroyed[tostring(id)] = true
end

function SceneryTracker:onDCSEvent(event)
	if event.id ~= world.event.S_EVENT_DEAD then
		Logger:debug("onDCSEvent() - bldgPersist not DEAD event, ignoring")
		return
	end
	local obj = event.initiator
	if obj:getCategory() == Object.Category.SCENERY then
		self:addObject(obj:getName())
	end
end

return SceneryTracker
