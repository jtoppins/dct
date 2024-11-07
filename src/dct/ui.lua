-- SPDX-License-Identifier: LGPL-3.0

-- UI.
-- Various convience functions and classes to interact with DCS's UI APIs.

require("lfs")
require("libs")

local __ui = {}

local requireroot = "dct.ui."
local syspath = libs.utils.join_paths(dct.modpath, "lua", "dct", "ui")

for file in lfs.dir(syspath) do
	local st, _, cap1 = string.find(file, "([^.]+)%.lua$")

	if st then
		__ui[cap1] = require(requireroot..cap1)
	end
end

return __ui
