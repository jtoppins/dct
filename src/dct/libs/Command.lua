-- SPDX-License-Identifier: LGPL-3.0

--- Command class to run a deferred function.
-- @classmod dct.libs.Command

-- DCS sanitizes its environment so we have to keep a local reference to
-- the os table.
local myos = require("os")
require("libs")

local class = libs.classnamed
local utils = libs.utils
local check = libs.check

local function execute(self, time)
	local args = utils.shallowclone(self.args)
	self._logger:debug("executing: %s", self.name)
	table.insert(args, time)
	return pcall(self.func, unpack(args))
end

local function timedexecute(self, time)
	local tstart = myos.clock()
	local results = { execute(self, time) }
	self._logger:debug("'%s' exec time: %5.2fms", self.name,
		(myos.clock()-tstart)*1000)
	return unpack(results)
end

local cmdpriority = {
	["UI"]     = 10,
	["NORMAL"] = 64,
}

--- Provides a basic Command class to call an arbitrary function
-- at a later time via the Command's execute function.
local Command = class("Command")

--- Class constructor.
-- @tparam number delay amount of delay in seconds before the command is run.
-- @tparam string name name of the Command, used in log output to
--   differentiate.
-- @tparam function func the function to execute later. The function should
--   return either a number representing how long the command should be
--   requeued for before being executed again, otherwise nil to signal the
--   command should not be requeue.
-- @param ... arguments to pass to the function
function Command:__init(delay, name, func, ...)
	self._logger = dct.libs.Logger.getByName("Command")
	self.delay = check.number(delay)
	self.name = check.string(name)
	self.func = check.func(func)
	self.prio = cmdpriority.NORMAL
	self.args = {select(1, ...)}
	self.requeueOnError = false
	self.PRIORITY = nil

	if (dct.settings and dct.settings.server and
	    (dct.settings.server.debug == true and
	     dct.settings.server.profile == true)) then
		self.execute = timedexecute
	end
end

--- General priority of the command.
-- lower value is higher priority; total of 127 priority values
Command.PRIORITY = cmdpriority

--- Set if the command should be requeued on error.
function Command:setRequeue(state)
	self.requeueOnError = check.bool(state)
end

--- Execute the deferred function.
-- The deferred function is called in a protected context where the
-- function can take an arbitrary parameter list and returns the same
-- number of values as if the function was called directly.
-- If profile and debug settings are true a different execute function will
-- be enabled which tracks how long the deferred function takes to execute.
-- This could be beneficial when trying to debug stuttering.
-- @param self reference to Command object
-- @param time time-step the command is executed
-- @treturn[1] bool true the command executed without error
-- @treturn[1] nil do not requeue the command
-- @treturn[2] bool true the command executed without error
-- @treturn[2] number delay time the command should be requeued for
-- @treturn[3] bool false the command experienced an error
-- @treturn[3] string error message
Command.execute = execute

return Command
