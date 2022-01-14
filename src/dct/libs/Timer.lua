--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- A count-up Timer
--
-- interface:
--   * start   - start the timer
--   * stop    - stop the timer
--   * reset   - reset timer to zero, returns the value of the counter
--               before reset
--   * update  - update the timer, uses timefunc to determine the elapsed
--               time between updates, returns the time delta between
--               updates
--   * expired - has the timer reached its timeout limit
--   * remain  - how many seconds remain
--   * extend  - extend the timer by 'time' time
--]]

local Timer = require("libs.namedclass")("Timer")
function Timer:__init(timeout, timefunc)
	self.timeoutlimit = timeout or math.huge
	self.timefunc = timefunc or timer.getAbsTime
	assert(type(self.timefunc) == "function", "timefunc must be a function")
	assert(type(timeout) == "number" and timeout > 0,
		"timeout must be a number and greater than zero")
	self.timeout = 0
	self.curtime = nil
end

function Timer:start()
	self.curtime = self.timefunc()
end

function Timer:stop()
	self.curtime = nil
end

function Timer:reset(limit)
	local val = self.timeout
	self.timeoutlimit = limit or self.timeoutlimit
	self.timeout = 0
	return val
end

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

function Timer:expired()
	return self.timeout >= self.timeoutlimit
end

function Timer:remain()
	local remain = self.timeoutlimit - self.timeout
	if remain < 0 then
		remain = 0
	end
	return remain, self.curtime
end

function Timer:extend(time)
	self.timeoutlimit = self.timeoutlimit + time
end

return Timer
