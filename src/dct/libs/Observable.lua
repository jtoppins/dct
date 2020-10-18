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
end

function Observable:addObserver(asset)
	assert(asset, "value error: 'asset' must not be nil")
	if type(asset.onDCTEvent) ~= "function" then
		Logger:error(
			string.format("asset(%s) does not implement 'onDCTEvent'",
				asset.name))
		return
	end
	Logger:debug("adding observer("..asset.name..")")
	self._observers[asset.name] = true
end

function Observable:removeObserver(name)
	assert(type(name) == "string", "value error: 'name' must be a string")
	self._observers[name] = nil
end

function Observable:onNotify(event)
	for observer, _ in pairs(self._observers) do
		local asset = require("dct.Theater").singleton():
			getAssetMgr():getAsset(observer)
		if asset == nil then
			Logger:debug(string.format(
				"asset(%s) appears to not exist removing observer",
				observer))
			self:removeObserver(observer)
		else
			Logger:debug("executing observer: "..observer)
			asset:onDCTEvent(event)
		end
	end
end

return Observable
