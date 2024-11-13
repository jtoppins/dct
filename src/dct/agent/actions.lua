-- SPDX-License-Identifier: LGPL-3.0

require("lfs")
require("libs")

local __actions = {}

local requireroot = "dct.agent.actions."
local syspath = libs.utils.join_paths(dct.modpath,
				      "lua", "dct", "agent", "actions")

-- TODO: validate that there does not exist classes of the same name.
for file in lfs.dir(syspath) do
	local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

	if st then
		local c = require(requireroot..cap1)
		__actions[c.__clsname] = c
	end
end

return __actions
