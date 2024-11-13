-- SPDX-License-Identifier: LGPL-3.0

require("lfs")
require("libs")

local __goals = {}

local requireroot = "dct.agent.goals."
local syspath = libs.utils.join_paths(dct.modpath,
				      "lua", "dct", "agent", "goals")

for file in lfs.dir(syspath) do
	local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

	if st then
		local c = require(requireroot..cap1)
		__goals[c.__clsname] = c
	end
end

return __goals
