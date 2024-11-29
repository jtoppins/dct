-- SPDX-License-Identifier: LGPL-3.0

require("libs")

local class         = libs.classnamed
local System        = require("dct.libs.System")
local builtin_codenames = require("dct.systems.data.codenamedb")

local CodenameDB = class("CodenameDB", System)

--- Enable this system by default.
CodenameDB.enabled = true

--- Constructor.
function CodenameDB:__init(theater)
	System.__init(self, theater, System.PRIORITY.ADDON)
	self._db = builtin_codenames
end

-- no initialize or start methods needed

function CodenameDB:overwrite(assettype, newtbl)
	self._db[assettype] = newtbl
end

--- generate a codename.
function CodenameDB:genCodename(objtype)
	local typetbl = self._db[objtype]

	if typetbl == nil then
		typetbl = self._db.default
	end

	local idx = math.random(1, #typetbl)
	return typetbl[idx]
end

return CodenameDB
