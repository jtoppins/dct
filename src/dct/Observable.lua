--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Observable interface
--]]

local class  = require("libs.class")
local Logger = require("dct.Logger").getByName("Observable")

local Observable = class()
function Observable:__init()
	self._observers = {}
	-- TODO: might need to implement a __mode metatable
	-- to implement weak key & value references
end

function Observable:registerHandler(func, ctx)
	assert(type(func) == "function", "func must be a function")
	-- ctx must be non-nil otherwise upon insertion the index which
	-- is the function address will be deleted.
	assert(ctx ~= nil, "ctx must be a non-nil value")

	if self._observers[func] ~= nil then
		Logger:error("func("..tostring(func)..") already set - skipping")
		return
	end
	Logger:debug("adding handler("..tostring(func)..")")
	self._observers[func] = ctx
end

function Observable:removeHandler(func)
	assert(type(func) == "function", "func must be a function")
	self._observers[func] = nil
end

function Observable:onEvent(event)
	for observer, ctx in pairs(self._observers) do
		Logger:debug("executing handler: "..tostring(observer))
		observer(ctx, event)
	end
end

return Observable
