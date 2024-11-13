-- SPDX-License-Identifier: LGPL-3.0

require("lfs")
require("libs")

local __actions = {}

local requireroot = "dct.agent.actions."
local syspath = libs.utils.join_paths(dct.modpath,
				      "lua", "dct", "agent", "actions")

for file in lfs.dir(syspath) do
	local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

	if st then
		local c = require(requireroot..cap1)
		assert(__actions[c.__clsname] == nil, string.format(
			"duplicate action class names, conflicting action: %s",
			libs.utils.join_paths(syspath, file)))
		__actions[c.__clsname] = c
	end
end

return __actions
