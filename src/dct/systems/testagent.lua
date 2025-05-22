-- SPDX-License-Identifier: LGPL-3.0

--- Autodetects a group spawn and attaches an Agent to it.

require("libs")
--local Command   = require("dct.libs.Command")
local System    = require("dct.libs.System")
local DCTEvents = require("dct.libs.DCTEvents")

local TestAgent = libs.classnamed("TestAgent", System, DCTEvents)
TestAgent.enabled = true

--- Constructor.
function TestAgent:__init(theater)
	System.__init(self, theater, System.PRIORITY.ADDON)
	DCTEvents.__init(self)

	self:_overridehandlers({
		[world.event.S_EVENT_BIRTH] = self.handleBirth,
	})
end

function TestAgent:initialize()
	self._theater:addObserver(self.onDCTEvent, self,
				  self.__clsname..".onDCTEvent")
	return true
end

function TestAgent:start()
	self._assetmgr = self._theater:getSystem(System.SYSTEMALIAS.ASSETMGR)
	--[[
	local cmd = Command(self.updaterate, self.__clsname..".update",
			    self.update, self)
	cmd:setRequeue(true)
	self._theater:queueCommand(cmd)
	--]]

end

function TestAgent:handleBirth(event)
	local grp = event.initiator:getGroup()

	if grp == nil or
	   self._assetmgr:getAsset(grp:getName()) ~= nil then
		return
	end

	local agent = dct.agent.Agent.fromDCSGroup(grp, true)

	if agent ~= nil then
		self._assetmgr:add(agent)
	end
end

return TestAgent
