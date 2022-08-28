--- SPDX-License-Identifier: LGPL-3.0

local WS = require("dct.assets.worldstate")

local SensorsSet = require("libs.namedclass")("SensorsSet", WS.Action)
function SensorsSet:__init(agent, cost)
	WS.Action.__init(self, agent, cost, {}, {
		WS.Property(WS.ID.SENSORSON, WS.Property.ANYHANDLE),
	})
end

function SensorsSet:enter()
	local prop = self.agent:currgoal():WS():get(WS.ID.SENSORSON)
	for _, grp in self.agent:iterateGroups(self.agent.filter_no_controller) do
		local dcsgrp = Group.getByName(grp.data.name)
		if dcsgrp ~= nil then
			dcsgrp:enableEmission(prop.value)
		end
	end
	self.agent:WS():get(prop.id).value = prop.value
end

return SensorsSet
