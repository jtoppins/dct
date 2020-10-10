--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides config facilities.
--]]

local servercfgs  = require("dct.settings.server")
local theatercfgs = require("dct.settings.theater")
local config     = nil

--[[
-- We have a few levels of configuration:
-- 	* server defined config file; <dcs-saved-games>/Config/dct.cfg
-- 	* theater defined configuration; <theater-path>/settings/<config-files>
-- 	* default config values
-- simple algorithm; assign the defaults, then apply the server and
-- theater configs
--]]
local function settings()
	if config ~= nil then
		return config
	end

	config = servercfgs({})
	config = theatercfgs(config)
	return config
end

return settings
