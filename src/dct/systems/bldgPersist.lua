--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a basic building persisntence system.
--]]

local class       = require("libs.class")
local Logger      = require("dct.Logger").getByName("bldgPersist")


local bldgPersist = class()

function bldgPersist:__init(theater)
  self.destroyedBldgs = {}
  self._theater = theater
  self._theater:registerHandler(self.onDCSEvent, self)
end

function bldgPersist:blowBuildings()
  for _, bldg in pairs(self.destroyedBldgs) do
    local id = tonumber(bldg)
    local obj = {id_ = id}
    local pt = Object.getPoint(obj)
    trigger.action.explosion(pt, 1000)
  end
end

function bldgPersist:restoreState(destroyedBldgs)
  self.destroyedBldgs = destroyedBldgs
  self:blowBuildings()
end

function bldgPersist:onDCSEvent(event)
  if event.id ~= world.event.S_EVENT_DEAD then
    Logger:debug(string.format("onDCSEvent() - bldgPersist not DEAD event, ignoring"))
    return
  end
  local obj = event.initiator
  if obj:getCategory() == Object.Category.SCENERY then
    table.insert(self.destroyedBldgs, tostring(obj:getName()))
    env.info("Building ID: "..tostring(obj:getName()).." added to destroyed list")
  end
end

function bldgPersist:returnList()
  return self.destroyedBldgs
end

return bldgPersist