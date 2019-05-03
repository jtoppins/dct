--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

require("testlibs")
local utils = require("libs.utils")
dctsettings = {
	["missioncfg"] = true,
}
require("dct")

local function main()
	local cfgvalidation = {
		["theaterpath"] = lfs.tempdir() .. utils.sep .. "theater",
		["debug"]       = false,
		["profile"]     = false,
		["servercfg"]   = true,
		["missioncfg"]  = true,
	}

	for k, v in pairs(cfgvalidation) do
		assert(dct.settings[k] == v, "dct.settings unexpected field '"..k.."'")
		--print("dct.settings: '"..k.."' = '"..tostring(v).."'")
	end

	for k, v in pairs(dct.settings) do
		assert(cfgvalidation[k] == v, "dct.settings unexpected field '"..k.."'")
		--print("dct.settings2: '"..k.."' = '"..tostring(v).."'")
	end

	return 0
end

os.exit(main())
