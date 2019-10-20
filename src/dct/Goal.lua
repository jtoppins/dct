--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage goals.
--]]

local goalenums  = require("dct.goals.enum")
local DamageGoal = require("dct.goals.DamageGoal")
local Logger     = require("dct.Logger").getByName("Goal")

--[[
-- data - a description of a Goal object, its fields are:
--
--   * [required] goaltype - defines the specific goal object to create
--   * [required] objtype  - the type of DCS object to be monitored
--   * [required] value    - an opaque value defining further details about
--                           a specific goal type, for example a damage type
--                           goal would define a number for how much damage
--                           a DCS game object would need to take before it
--                           was considered 'complete'.
--   * [optional] priority - specifies the overall priority of the goal
--                           right now only PRIMARY goals are tracked in
--                           objectives. (Default: is to set goal priority
--                           to PRIMARY)
--
-- name - the name of the DCS object
--]]
local Goal = {}
function Goal.factory(name, data)
	-- TODO: validate all fields either here or in BaseGoal.__init()
	assert(type(name) == 'string', "value error, name")
	assert(type(data) == 'table', "value error, data")

	local goal = nil

	data.name = name
	if data.goaltype == goalenums.goaltype.DAMAGE then
		goal = DamageGoal(data)
	else
		if debug and type(debug.traceback) == 'function' then
			Logger:error("invalid goaltype; traceback:\n"..debug.traceback())
		end
	end
	return goal
end

Goal.priority = goalenums.priority
Goal.objtype  = goalenums.objtype
Goal.goaltype = goalenums.goaltype

return Goal
