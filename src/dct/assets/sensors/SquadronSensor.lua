-- SPDX-License-Identifier: LGPL-3.0

local class = require("libs.namedclass")
local utils = require("libs.utils")

-- TODO: Spawners, to get around the Agent class requirement to have a
-- backing Template() object we reference a generic "tactical" template
-- during the Agent creation using a custom Agent creation process.

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

-- Represents a Squadron.
--
-- Squadron<AssetBase>:
--   tracks and manages players slots associated with this squadron.
local Squadron = class("Squadron")
function Squadron:__init(template)
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

function Squadron:spawn()
	self._logger:debug("spawned")
end

return Squadron

--[[
local function associate_slots(ab)
	local filter = function(a)
		if a.type == dctenum.assetType.PLAYERGROUP and
		   a.airbase == ab.name and a.owner == ab.owner then
			return true
		end
		return false
	end
	local assetmgr = dct.Theater.singleton():getAssetMgr()
	local regionmgr = dct.Theater.singleton():getRegionMgr()

	-- Associate player slots that cannot be autodetected by using
	-- a list provided by the campaign designer. First look up the
	-- template defining the airbase so that slots can be updated
	-- without resetting the campaign state.
	local region = regionmgr:getRegion(ab.rgnname)
	local tpl = region:getTemplateByName(ab.tplname)
	for _, name in ipairs(tpl.players or {}) do
		local asset = assetmgr:getAsset(name)
		if asset and asset.airbase == nil then
			asset.airbase = ab.name
		end
	end

	for name, _ in pairs(assetmgr:filterAssets(filter)) do
		local asset = assetmgr:getAsset(name)
		if asset then
			ab:addSubordinate(asset)
			if asset.parking then
				ab._parking_occupied[asset.parking] = true
			end
		end
	end
end

local function filterPlayerGroups(sublist)
	local subs = {}
	for subname, subtype in pairs(sublist) do
		if subtype ~= dctenum.assetType.PLAYERGROUP then
			subs[subname] = subtype
		end
	end
	return subs
end
--]]
