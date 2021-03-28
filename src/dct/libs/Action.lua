--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- A simple Action interface.
-- Represents an activity in a mission plan
-- to be completed for mission progression.
--]]

local State = require("dct.libs.State")

local Action = require("libs.namedclass")("Action", State)
function Action:__init(--[[tgtasset]])
	self._logger = require("dct.libs.Logger").getByName("Action")
end

Action.update = nil

-- Perform check for action completion here
-- Examples: target death criteria, F10 command execution, etc
function Action:complete()
	return false
end

--[[
-- The human readable description of the task.
-- This will be presented to the user in the mission briefing.
function Action:getHumanDesc()
end
--]]

return Action
