--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

local class = require("libs.class")
local json = require("libs.json")

local Objective = class()
function Objective:__init(template, region)
	self.__spawned = false
	self.__tpl     = template
	self.__rgn     = region
	-- TODO: this name doesn't guarantee uniqueness, eventually a
	-- template function will be needed to generate a unique name
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
		-- off to the Theater so we can associate a single map of groups
		-- to objective objects. Then the Theater class can register
		-- a single event handler to manage various things like S_EVENT_HIT,
		-- S_EVENT_DEAD, etc.
		self.__spawned = true
	end
end

function Objective:encode()
  return json:encode({ ["templateName"] = self.name, ["regionName"] = self.__rgn, ["spawned"] = self.__spawned, })
end


return Objective
