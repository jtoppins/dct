--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Observable interface
--]]

local class  = require("libs.class")
local Logger = dct.Logger.getByName("Observable")

local Observable = class()
function Observable:__init()
	self._observers = {}
	setmetatable(self._observers, { __mode = "k", })
end

function Observable:addObserver(func, ctx, name)
	assert(type(func) == "function", "func must be a function")
	-- ctx must be non-nil otherwise upon insertion the index which
	-- is the function address will be deleted.
	assert(ctx ~= nil, "ctx must be a non-nil value")
	name = name or "unknown"

	if self._observers[func] ~= nil then
		Logger:error("func("..tostring(func)..") already set - skipping")
		return
	end
	Logger:debug("adding handler("..name..")")
	self._observers[func] = { ["ctx"] = ctx, ["name"] = name, }
end

function Observable:removeObserver(func)
	assert(type(func) == "function", "func must be a function")
	self._observers[func] = nil
end

function Observable:notify(event)
	for handler, val in pairs(self._observers) do
		Logger:debug("executing handler: "..val.name)
		handler(val.ctx, event)
	end
end

return Observable
