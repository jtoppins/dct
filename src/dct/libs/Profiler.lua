--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides profiling facilities.
--]]

local class  = require("libs.class")

local settings = _G.dct.settings
local prof = nil
local Profiler = class()

function Profiler.getProfiler()
	if prof == nil then
		prof = Profiler()
	end
	return prof
end

function Profiler:__init()
	self:setProfiling(settings.profile or false)
	self.__pfltbl  = {}
end

function Profiler:setProfiling(onoff)
	assert(type(onoff) == "boolean", "invalid onoff value, not a boolean")
	self.__profile = onoff
end

function Profiler:profileStart(name)
	if self.__profile ~= true then
		return
	end
	self.__pfltbl[name] = timer.getTime()*1000
end

function Profiler:profileStop(name)
	if self.__profile ~= true then
		return
	end
	local pend = timer.getTime()*1000
	env.info("PROFILE-"..name.." took "..(pend - self.__pfltbl[name])..
		"ms to execute")
end

return Profiler
