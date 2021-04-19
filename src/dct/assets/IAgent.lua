--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- IAgent<DCSObjects>
--]]

local dctenum = require("dct.enum")
local aitasks = require("dct.ai.tasks")
local DCSObjects = require("dct.assets.DCSObjects")

local IAgent = require("libs.namedclass")("IAgent", DCSObjects)
function IAgent:__init(template)
	DCSObjects.__init(self, template)
end

local function _do_one_obj(name, lookup, tasktbl, reset)
	local taskfunc = aitasks.pushTask
	if reset then
		taskfunc = aitasks.setTask
	end

	local obj = lookup(name)
	if obj == nil or type(obj.getController) ~= "function" or
	   obj:getController() == nil then
		return
	end
	aitasks.execute(obj:getController(), tasktbl, taskfunc)
end

local nocontroller = {
	[dctenum.UNIT_CAT_SCENERY]   = true,
	[Unit.Category.STRUCTURE] = true,
}

function IAgent:doTasks(tasktbl, reset)
	if not self:isSpawned() then
		return
	end

	for _, grp in pairs(self._assets) do
		if nocontroller[grp.category] == nil then
			_do_one_obj(grp.data.name, Group.getByName, tasktbl, reset)
		end
	end
end

function IAgent:doTasksForGroups(namelist, tasktbl, reset)
	if not self:isSpawned() then
		return
	end

	for _, name in ipairs(namelist) do
		_do_one_obj(name, Group.getByName, tasktbl, reset)
	end
end

function IAgent:doTasksForUnits(namelist, tasktbl, reset)
	if not self:isSpawned() then
		return
	end

	for _, name in ipairs(namelist) do
		_do_one_obj(name, Unit.getByName, tasktbl, reset)
	end
end
