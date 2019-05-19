--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides DCS stubs for the mission scripting environment.
--]]

require("lfs")
function lfs.writedir()
	return "./data"
end

function lfs.tempdir()
	return "./data"
end
require("socket")

local env = {}
env.mission = {}
env.mission.theatre = "Test Theater"
env.mission.sortie  = "test mission"
function env.getValueDictByKey(s)
	return s
end

function env.warning(msg, showbox)
	print(msg)
end
function env.info(msg, showbox)
	print(msg)
end
function env.error(msg, showbox)
	print(msg)
end
_G.env = env

local Unit = {}
Unit.Category = {
	["AIRPLANE"]    = 0,
	["HELICOPTER"]  = 1,
	["GROUND_UNIT"] = 2,
	["SHIP"]        = 3,
	["STRUCTURE"]   = 4,
}
_G.Unit = Unit

local timer = {}
function timer.getTime()
	return socket.gettime()
end
function timer.scheduleFunction(fnc, data, nexttime)
end
_G.timer = timer

local coalition = {}
function coalition.addGroup(_, cat, data)
	test.debug("SPAWN: spawn group, type:" .. cat .. ", name: " .. data.name)
	check.spawngroups = check.spawngroups + 1
end

function coalition.addStaticObject(_, data)
	test.debug("SPAWN: spawn static, type:" .. type(data) .. ", name: " .. data.name)
	check.spawnstatics = check.spawnstatics + 1
end
_G.coalition = coalition

local world = {}
function world.addEventHandler(handler)
end
_G.world = world
