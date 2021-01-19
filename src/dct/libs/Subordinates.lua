--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Subordinate interface that has observable properties.
-- This means the object inheriting this class has subordinate objects
-- that are assumed to be observers of the object as well.
--]]

local class = require("libs.class")
local AssetBase = require("dct.assets.AssetBase")
local Logger = dct.Logger.getByName("Asset")

local Subordinates = class()
function Subordinates:__init()
	self._subordinates = {}
	if not self._subeventhandlers then
		self._subeventhandlers = {}
	end
end

--[[
-- Process a DCS or DCT event associated w/ an asset.
-- Returns: none
--]]
function Subordinates:onSubEvent(event)
	local handler = self._subeventhandlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

function Subordinates:addSubordinate(asset)
	assert(asset ~= nil and asset:isa(AssetBase),
		"value error: 'asset' must be a super class of AssetBase")
	self._subordinates[asset.name] = asset.type
end

function Subordinates:spawn_despawn(action)
	Logger:debug(string.format("%s(%s):spawn_despawn(%s) called",
		self.__clsname, self.name, action))
	local theater = dct.Theater.singleton()
	for name, _ in pairs(self._subordinates) do
		local asset = theater:getAssetMgr():getAsset(name)
		if asset then
			if action == "spawn" then
				-- have the subordinate asset observe the parent
				self:addObserver(asset.onDCTEvent, asset, asset.name)
				-- have the parent observe the subordinate
				asset:addObserver(self.onSubEvent, self, self.name)
				if not asset:isSpawned() then
					asset[action](asset)
				end
			else
				asset[action](asset)
			end
		else
			Logger:info(string.format(
				"%s(%s):spawn_despawn - asset(%s) doesn't exist, "..
				"removing subordinate",
				self.__clsname, self.name, name))
			self:removeSubordinate(name)
		end
	end
end

function Subordinates:removeSubordinate(name)
	self._subordinates[name] = nil
end

return Subordinates
