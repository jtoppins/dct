--[[
-- SPDX-License-Identifier: LGPL-3.0
--
--Represents the action of killing a target.
--Once an asset has 'died' i.e. met it's death goal
--the action is considered complete.
--]]

local class = require("libs.namedclass")
local Action = require("dct.libs.Action")

local KillTarget = class("KillTarget", Action)
function KillTarget:__init(tgtasset)
	self.target = tgtasset
end

--Perform check for action completion here
--Examples: target death criteria, F10 command execution, etc
function KillTarget:complete()
	return self.target:isComplete()
end

return KillTarget
