--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides logging facilities.
--]]

local class  = require("libs.class")

local settings = _G.dct.settings.server
local loggers = {}
local Logger = class()

Logger.level = {
	["error"] = 0,
	["warn"]  = 1,
	["info"]  = 2,
	["debug"] = 4,
}

function Logger:__init(name)
	assert(name, "value error: name must be provided")
	self.name   = name
	self.fmtstr = "DCT|%s: %s"
	self:setLevel(Logger.level["warn"])
	if settings.logger ~= nil and settings.logger[name] ~= nil then
		self:setLevel(Logger.level[settings.logger[name]])
	elseif settings.debug == true then
		self:setLevel(Logger.level["debug"])
	end
	self.getByName = nil
	self.level = nil
end

function Logger:setLevel(lvl)
	assert(type(lvl) == "number", "invalid log level, not a number")
	assert(lvl >= Logger.level["error"] and lvl <= Logger.level["debug"],
			"invalid log level, out of range")
	self.__lvl = lvl
end

function Logger:error(msg)
	env.error(string.format(self.fmtstr, self.name, msg),
		settings.showErrors)
end

function Logger:warn(msg)
	if self.__lvl < Logger.level["warn"] then
		return
	end
	env.warning(string.format(self.fmtstr, self.name, msg), false)
end

function Logger:info(msg)
	if self.__lvl < Logger.level["info"] then
		return
	end
	env.info(string.format(self.fmtstr, self.name, msg), false)
end

function Logger:debug(msg)
	if self.__lvl < Logger.level["debug"] then
		return
	end
	env.info(string.format("DEBUG-"..self.fmtstr, self.name, msg), false)
end

function Logger.getByName(name)
	local l = loggers[name]
	if l == nil then
		l = Logger(name)
		loggers[name] = l
	end
	return l
end

return Logger
