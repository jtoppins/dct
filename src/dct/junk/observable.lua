--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Observable interface
--]]

local class  = require("libs.class")
local Logger = require("dct.logger").getByName("observable")

local Observable = class()
function Observable:__init()
	self._observers = {}
	-- TODO: might need to implement a __mode metatable
	-- to implement weak key & value references
end

function Observable:registerHandler(func, ctx)
	assert(type(func) == "function", "func must be a function")
	assert(ctx ~= nil, "ctx must be a non-nil value")

	if self._observers[func] ~= nil then
		Logger:error("func("..tostring(func)..") already set - skipping")
		return
	end
	self._observers[func] = ctx
end

function Observable:removeHandler(func)
	assert(type(func) == "function", "func must be a function")
	self._observers[func] = nil
end

function Observable:onEvent(event)
	for observer, ctx in pairs(self._observers) do
		observer(ctx, event)
	end
end

return Observable
