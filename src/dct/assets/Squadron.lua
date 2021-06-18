--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Squadron.
--
-- Squadron<AssetBase>:
--   tracks and manages players slots associated with this squadron.
--]]

local class = require("libs.namedclass")
local utils = require("libs.utils")
local AssetBase = require("dct.assets.AssetBase")

local function associate_slots(sqdn)
	local filter = function(a)
		if a.type == require("dct.enum").assetType.PLAYERGROUP and
		   a.squadron == sqdn.name and a.owner == sqdn.owner then
			return true
		end
		return false
	end
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	for name, _ in pairs(assetmgr:filterAssets(filter)) do
		local asset = assetmgr:getAsset(name)
		if asset and asset.airbase == nil then
			asset.airbase = sqdn.airbase
		end
	end
end

local Squadron = class("Squadron", AssetBase)
function Squadron:__init(template)
	AssetBase.__init(self, template)
	self:_addMarshalNames({
		"ato",
		"airbase",
		"payloadlimits",
	})
end

function Squadron.assettypes()
	return {
		require("dct.enum").assetType.SQUADRONPLAYER,
	}
end

function Squadron:_completeinit(template)
	AssetBase._completeinit(self, template)
	self.ato = utils.deepcopy(template.ato)
	self.payloadlimits = utils.deepcopy(template.payloadlimits)
	self.airbase = template.airbase
	local ab = Airbase.getByName(self.airbase)
	if ab == nil then
		self._location = { x = 0, y = 0, z = 0 }
		self._logger:error("Airbase(%s) does not exist", self.airbase)
	else
		self._location = ab:getPoint()
	end
	associate_slots(self)
	self._logger:debug("payloadlimits: %s",
		require("libs.json"):encode_pretty(self.payloadlimits))
	self._logger:debug("ato: %s",
		require("libs.json"):encode_pretty(self.ato))
end

function Squadron:getATO()
	return self.ato
end

function Squadron:getPayloadLimits()
	return self.payloadlimits
end

--[[
function Squadron:spawn()
	AssetBase.spawn(self)
	self._logger:debug("spawned")
end
--]]

return Squadron
