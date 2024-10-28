-- SPDX-License-Identifier: LGPL-3.0

--- A count-up Timer.
-- The timer is not cycle accurate and requires the `update` method to be
-- called periodically to progress the timer to expiration. Additionally,
-- you must call `start` method before the timer will actually start counting
-- even if the `update` method is called.
-- @module dct.libs.Timer

require("libs")

--- Count-up Timer.
-- @type Timer
local Timer = libs.classnamed("Timer")

--- Constructor.
-- Create a Timer instance using `timefunc` as the timer source and
-- `timeout` as the number of seconds until the timer expires. The
-- timer source is commonly `os.clock` to time against wall clock
-- or `timer.getAbsTime` to get the simulation time step in DCS.
-- @param timeout [number] how long the timer will count in seconds.
-- @param timefunc [function] callback to get the time or defaults to
--                 `timer.getAbsTime`.
function Timer:__init(timeout, timefunc)
	self.timeoutlimit = timeout or math.huge
	self.timefunc = timefunc or timer.getAbsTime
	assert(type(self.timefunc) == "function", "timefunc must be a function")
	assert(type(timeout) == "number" and timeout > 0,
		"timeout must be a number and greater than zero")
	self.timeout = 0
	self.curtime = nil
end

--- Check if the timer is started.
-- @return bool, true means timer is started.
function Timer:started()
	return self.curtime ~= nil
end

--- Start the timer.
function Timer:start()
	self.curtime = self.timefunc()
end

--- Stop the timer.
function Timer:stop()
	self.curtime = nil
end

--- Reset timer to zero, returns the value of the counter before reset.
-- @param limit reset to new timeout if nil keeps the old timeout length
-- @return how long the timer had been running in seconds.
function Timer:reset(limit)
	local val = self.timeout
	self.timeoutlimit = limit or self.timeoutlimit
	self.timeout = 0
	return val
end

--- Update the timer, uses timefunc to determine the elapsed
-- time between updates, returns the time delta between updates.
function Timer:update()
	if self.curtime == nil then
		return
	end
	local prevtime = self.curtime
	self.curtime = self.timefunc()
	local delta = self.curtime - prevtime
	self.timeout = self.timeout + delta
	return delta
end

--- Has the timer reached its timeout limit.
function Timer:expired()
	return self.timeout >= self.timeoutlimit
end

--- How many seconds remain.
function Timer:remain()
	local remain = self.timeoutlimit - self.timeout
	if remain < 0 then
		remain = 0
	end
	return remain, self.curtime
end

--- Extend the timer by 'time' seconds.
-- @param time time in seconds to extend the timeout by.
function Timer:extend(time)
	self.timeoutlimit = self.timeoutlimit + time
end

return Timer
