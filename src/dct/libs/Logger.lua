-- SPDX-License-Identifier: LGPL-3.0

--- Provides logging facilities.
-- @classmod dct.libs.Logger

require("libs")

local class  = libs.class
local loggers = {}
local Logger = class()

--- Logger logging level.
-- Passed to setLevel to set the associated logging level.
Logger.level = {
	["error"] = 0,
	["warn"]  = 1,
	["info"]  = 2,
	["debug"] = 4,
}

--- Constructor.
-- @param name facility name
function Logger:__init(name)
	local settings = dct.settings.server
	self.name   = libs.check.string(name)
	self.fmtstr = "DCT|%s: %s"
	self.dbgfmt = "DEBUG-DCT|%s: %s"
	self:setLevel(Logger.level["warn"])
	if settings.logger ~= nil and settings.logger[name] ~= nil then
		self:setLevel(Logger.level[settings.logger[name]])
	elseif settings.debug == true then
		self:setLevel(Logger.level["debug"])
	end
	self.getByName = nil
	self.level = nil
	if settings.showErrors then
		self.errors = 0
		self.showErrors = true
	end
end

--- Sets the logging level of the logger object.
-- @param lvl log level to set
function Logger:setLevel(lvl)
	assert(type(lvl) == "number", "invalid log level, not a number")
	assert(lvl >= Logger.level["error"] and lvl <= Logger.level["debug"],
			"invalid log level, out of range")
	self.__lvl = lvl
end

function Logger:_log(sink, fmtstr, userfmt, showErrors, ...)
	sink(string.format(fmtstr, self.name,
		string.format(userfmt, ...)), showErrors)
end

--- Log an error message.
-- @param userfmt format string same as string.format
-- @param ... values to format
function Logger:error(userfmt, ...)
	if self.showErrors then
		self.errors = self.errors + 1
		if self.errors > 3 then
			self:_log(env.error, self.fmtstr,
				"Supressing further messages from this logger\n"..
				"(check dcs.log for more errors)", true)
			self.showErrors = false
		end
	end
	self:_log(env.error, self.fmtstr, userfmt, self.showErrors, ...)
end

--- Log an warning message.
-- @param userfmt format string same as string.format
-- @param ... values to format
function Logger:warn(userfmt, ...)
	if self.__lvl < Logger.level["warn"] then
		return
	end
	self:_log(env.warning, self.fmtstr, userfmt, false, ...)
end

--- Log an info message.
-- @param userfmt format string same as string.format
-- @param ... values to format
function Logger:info(userfmt, ...)
	if self.__lvl < Logger.level["info"] then
		return
	end
	self:_log(env.info, self.fmtstr, userfmt, false, ...)
end

--- Log a debug message.
-- @param userfmt format string same as string.format
-- @param ... values to format
function Logger:debug(userfmt, ...)
	if self.__lvl < Logger.level["debug"] then
		return
	end
	self:_log(env.info, self.dbgfmt, userfmt, false, ...)
end

--- Get the logger associated with name.
-- @param name facility name
function Logger.getByName(name)
	local l = loggers[name]
	if l == nil then
		l = Logger(name)
		loggers[name] = l
	end
	return l
end

return Logger
