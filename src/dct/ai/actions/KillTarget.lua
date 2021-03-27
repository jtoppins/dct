--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents the action of killing a target.
-- Once an asset has 'died' i.e. met it's death goal
-- the action is considered complete.
--]]

local class = require("libs.namedclass")
local dctenum = require("dct.enum")
local Action = require("dct.libs.Action")

local KillTarget = class("KillTarget", Action)
function KillTarget:__init(tgtasset)
	assert(tgtasset ~= nil and tgtasset:isa(require("dct.assets.AssetBase")),
		"tgtasset is not a BaseAsset")
	self.tgtname = tgtasset.name
	self.complete = tgtasset:isDead()
	tgtasset:addObserver(self.onDCTEvent, self,
		self.__clsname..".onDCTEvent")
end

function KillTarget:onDCTEvent(event)
	if event.id ~= dctenum.event.DCT_EVENT_DEAD then
		return
	end

	self.complete = true
	event.initiator:removeObserver(self)
end

-- Perform check for action completion here
-- Examples: target death criteria, F10 command execution, etc
function KillTarget:complete()
	return self.complete
end

return KillTarget
