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

local Squadron = class("Squadron", AssetBase)
function Squadron:__init(template, region)
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"ato",
		"airbase",
		"payloadlimits",
	})
end

function Squadron:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	self.ato = utils.deepcopy(template.ato)
	self.payloadlimits = utils.deepcopy(template.payloadlimits)
	self.airbase = template.airbase
	self._logger:debug("payloadlimits: "..require("libs.json"):encode_pretty(self.payloadlimits))
	self._logger:debug("ato: "..require("libs.json"):encode_pretty(self.ato))
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
