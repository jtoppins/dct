-- SPDX-License-Identifier: LGPL-3.0

--- CheckPerEntry class.
-- Extends the Check class so that a table of similar elements can
-- be validated. For example;
--
-- ```
-- {
--     entry1 = {
--         key1 = "foo",
--         key2 = "bar",
--     },
--     entry2 = {
--         key1 = "baz",
--         key2 = "zoo",
--     }, ...
-- }
-- ```
--
-- Entries entry1 and entry2 have the same sets of keys just different
-- values. This class allows for an easy way to check this kind of
-- construct.
-- @classmod dct.libs.Check

require("libs")
local class    = libs.classnamed
local Check    = require("dct.libs.Check")

local CheckPerEntry = class("CheckPerEntry", Check)
function CheckPerEntry:checkEntry(data)
	return Check.check(self, data)
end

function CheckPerEntry:check(data)
	for key, val in pairs(data) do
		local ok, errkey, msg = self:checkEntry(val)
		if not ok then
			return false, key, string.format("`%s` %s",
				tostring(errkey), tostring(msg))
		end
	end
	return true
end

return CheckPerEntry
