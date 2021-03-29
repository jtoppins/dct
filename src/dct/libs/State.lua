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

--[[
-- factory - return an instance of a State class
--
--   typetbl - a table indexed by state id and value a reference to
--     a State class that is callable
--   id - the state type id specifying which specific State object
--     should be created
--]]
function State.factory(typetbl, id)
	local state = typetbl[id]
	assert(state, "unknown state type")
	return state()
end

return State
