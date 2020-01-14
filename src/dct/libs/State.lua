--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- A simple State interface.
--]]

local class = require("libs.class")

local State = class()
function State:enter(--[[asset]])
end

function State:exit(--[[asset]])
end

-- returns nil or a new state instance
function State:update(--[[asset]])
	return nil
end

-- returns nil or a new state instance
function State:onDCTEvent(--[[asset, event]])
	return nil
end

return State
