--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements an Objective Manager
--]]

local class = require("libs.class")

local MissionManager = class()
function MissionManager:__init()
--[[
--	various tables needed:
--		*objectives indexed by name (all objective names must be unique)
--		*per side & per region objective tables (allows "management" of the
--			front by spawning objectives in 'activated' regions)
--		*per side available objectives
--		*per side assigned objectives (simple table where keys are obj names)
--		*per side completed objectives (i.e. the goal state is met)
--]]
end



function MissionManager:addObjective(objective)
end

function MissionManager:getNewMission()
end

function Theater:addObjective(side, obj)
	-- TODO: for now do a simple storage of the objectives, it is assumed
	-- all objective names are unique
	self.objectives[obj.name] = obj
	self.dbgstats:incstat("obj", 1)
end

function MissionManager:regionActivate()
end

function Theater:spawnActive()
    -- TODO: for now we are just going to spawn everything
	for name, obj in pairs(self.objectives) do
		obj:spawn(self)
		self.logger:debug("Spawning: '"..name.."'")
		self.dbgstats:incstat("spawn", 1)
	end
end


return MissionManager
