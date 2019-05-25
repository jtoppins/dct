--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides config facilities.
--]]

require("lfs")
local utils = require("libs.utils")
local config = nil

-- We have 3 levels of config,
-- 	* mission defined configs
-- 	* server defined config file
-- 	* default config values
-- simple algorithm; assign the defaults, then apply the server, then
-- any mission level configs
local function settings(mcfg)
	if config ~= nil then
		return config
	end

	local path = lfs.writedir() .. utils.sep .. "Config" ..
		utils.sep .. "dct.cfg"
	local attr = lfs.attributes(path)

	config = {}
	-- config.luapath = lfs.writedir() .. "Scripts\\?.lua"
	--[[
	-- Note: Can't provide a server level package path as to require
	-- dct would require the package path to already be set. Nor can
	-- we provide a useful default because the package.path needs to
	-- be set before we get here.
	--]]
	config.theaterpath = lfs.tempdir() .. utils.sep .. "theater"
	config.debug       = false
	config.profile     = false
	config.statepath   = lfs.writedir()..env.mission.theatre..
		env.getValueDictByKey(env.mission.sortie)..".state"

	if attr ~= nil then
		local rc = pcall(dofile, path)
		assert(rc, "failed to parse: server config file, '" ..
		       path .. "' path likely doesn't exist")
		assert(dctserverconfig ~= nil,
			"no dctserverconfig structure defined")
		utils.mergetables(config, dctserverconfig)
		dctserverconfig = nil
	end

	utils.mergetables(config, mcfg)

	return config
end

return settings
