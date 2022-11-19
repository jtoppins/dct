-- SPDX-License-Identifier: LGPL-3.0

local class   = require("libs.namedclass")
local Check   = require("dct.templates.checkers.Check")

local CheckRadar = class("CheckRadar", Check)
function CheckRadar:__init()
	Check.__init(self, "Detection", {
		["radarupdate"] = {
			["default"] = 10,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Determines how quickly the Agent's detection model will update the
characters the Agent knows about.]],
		},
		["radarattrs"] = {
			["default"] = {},
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
List of unit attributes used to identify DCS units that should be queried
for their contacts.]],
		},
		["radardetection"] = {
			["default"] = { Controller.Detection.RADAR, },
			["type"] = Check.valuetype.TABLE,
			["description"] = [[
List of `Controller.Detection` values used when querying the DCS units
for their contact list.]],
		},
		["radarageout"] = {
			["default"] = 30,
			["type"] = Check.valuetype.INT,
			["description"] = [[
Time, in seconds, a contact will remain with the agent before it is removed.
]],
		},
	})
end

return CheckRadar
