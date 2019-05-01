--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

local class = require("libs.class")

local Objective = class()
function Objective:__init(template, gamestate)
	self.__spawned = false
	self.__tpl     = template
	self.name      = template.name
end

function Objective:isSpawned()
	return self.__spawned
end

function Objective:spawn()
	-- TODO: this will eventually need to be a dynamically constructed
	-- function based on what the template and objective is
	-- For now to test things just spawn everything from the template
	if not self:isSpawned() then
		self.__tpl:spawn()
		-- TODO: eventually the template spawn function will need to return
		-- all group names that are associated with this objective. So as not
		-- to register 300 event handlers, we need to hand this list of groups
		-- off to the GameState so we can associate a single map of groups
		-- to objective objects. Then the GameState class can register
		-- a single event handler to manage various things like S_EVENT_HIT,
		-- S_EVENT_DEAD, etc.
		self.__spawned = true
	end
end

return Objective
