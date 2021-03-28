--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- A count-up Timer
--
-- interface:
--   * reset   - reset timer to zero
--   * update  - update the timer, uses timefunc to determine the elapsed time
--               between updates
--   * expired - has the timer reached its timeout limit
--   * remain  - how many seconds remain
--   * extend  - extend the timer by 'time' time
--]]

local Timer = require("libs.namedclass")("Timer")
function Timer:__init(timeout, timefunc)
	self.timefunc = timefunc or timer.getAbsTime
	assert(type(self.timefunc) == "function", "timefunc must be a function")
	assert(type(timeout) == "number" and timeout > 0,
		"timeout must be a number and greater than zero")
	self.timeoutlimit = timeout
	self.timeout = 0
	self.curtime = self.timefunc()
end

function Timer:reset(limit)
	self.timeoutlimit = limit or self.timeoutlimit
	self.timeout = 0
	self.curtime = self.timefunc()
end

function Timer:update()
	local prevtime = self.curtime
	self.curtime = self.timefunc()
	self.timeout = self.timeout + (self.curtime - prevtime)
end

function Timer:expired()
	return self.timeout > self.timeoutlimit
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
