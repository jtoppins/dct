--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides DCS stubs for the mission scripting environment.
--]]

require("os")
local utils = require("libs.utils")

require("lfs")
lfs.dct_testdata = os.getenv("DCT_DATA_ROOT") or "."
function lfs.writedir()
	return lfs.dct_testdata
end

function lfs.tempdir()
	return lfs.dct_testdata .. utils.sep .. "mission"
end
require("socket")
local class = require("libs.class")

-- DCS Singletons
--
local env = {}
env.mission = {}
env.mission.theatre = "Test Theater"
env.mission.sortie  = "test mission"
function env.getValueDictByKey(s)
	return s
end

function env.warning(msg, showbox)
	print("WARN: "..msg)
end
function env.info(msg, showbox)
	print("INFO: "..msg)
end
function env.error(msg, showbox)
	print("ERROR: "..msg)
end
_G.env = env

local timer = {}
function timer.getTime()
	return socket.gettime()
end
function timer.scheduleFunction(fnc, data, nexttime)
end
_G.timer = timer

local coalition = {}
coalition.side = {}
coalition.side.NEUTRAL = 0
coalition.side.RED     = 1
coalition.side.BLUE    = 2

function coalition.addGroup(_, cat, data)
	test.debug("SPAWN: spawn group, type:" .. cat .. ", name: " .. data.name)
	check.spawngroups = check.spawngroups + 1
end

function coalition.addStaticObject(_, data)
	test.debug("SPAWN: spawn static, type:" .. type(data) .. ", name: " .. data.name)
	check.spawnstatics = check.spawnstatics + 1
end

local coaltbl = {
	-- BLUE Coalition
	[21] = {
		["name"] = "Australia",
		["side"] = coalition.side.BLUE,
	},
	[11] = {
		["name"] = "Belgium",
		["side"] = coalition.side.BLUE,
	},
	[8] = {
		["name"] = "Canada",
		["side"] = coalition.side.BLUE,
	},
	[28] = {
		["name"] = "Croatia",
		["side"] = coalition.side.BLUE,
	},
	[26] = {
		["name"] = "Czech Republic",
		["side"] = coalition.side.BLUE,
	},
	[13] = {
		["name"] = "Denmark",
		["side"] = coalition.side.BLUE,
	},
	[5] = {
		["name"] = "France",
		["side"] = coalition.side.BLUE,
	},
	[16] = {
		["name"] = "Georgia",
		["side"] = coalition.side.BLUE,
	},
	[6] = {
        ["name"] = "Germany",
		["side"] = coalition.side.BLUE,
	},
	[15] = {
		["name"] = "Israel",
		["side"] = coalition.side.BLUE,
	},
	[20] = {
		["name"] = "Italy",
		["side"] = coalition.side.BLUE,
	},
	[12] = {
		["name"] = "Norway",
		["side"] = coalition.side.BLUE,
	},
	[40] = {
		["name"] = "Poland",
		["side"] = coalition.side.BLUE,
	},
	[45] = {
		["name"] = "South Korea",
		["side"] = coalition.side.BLUE,
	},
	[9] = {
		["name"] = "Spain",
		["side"] = coalition.side.BLUE,
	},
	[46] = {
		["name"] = "Sweden",
		["side"] = coalition.side.BLUE,
	},
	[10] = {
        ["name"] = "The Netherlands",
		["side"] = coalition.side.BLUE,
	},
	[3] = {
		["name"] = "Turkey",
		["side"] = coalition.side.BLUE,
	},
	[4] = {
        ["name"] = "UK",
		["side"] = coalition.side.BLUE,
	},
	[1] = {
		["name"] = "Ukraine",
		["side"] = coalition.side.BLUE,
	},
	[2] = {
		["name"] = "USA",
		["side"] = coalition.side.BLUE,
	},
	[73] = {
		["name"] = "Oman",
		["side"] = coalition.side.BLUE,
	},
	[74] = {
		["name"] = "UAE",
		["side"] = coalition.side.BLUE,
	},

	-- RED Coalition
	[18] = {
		["name"] = "Abkhazia",
		["side"] = coalition.side.RED,
	},
	[24] = {
		["name"] = "Belarus",
		["side"] = coalition.side.RED,
	},
	[27] = {
		["name"] = "China",
		["side"] = coalition.side.RED,
	},
	[34] = {
		["name"] = "Iran",
		["side"] = coalition.side.RED,
	},
	[37] = {
		["name"] = "Kazakhstan",
		["side"] = coalition.side.RED,
	},
	[38] = {
		["name"] = "North Korea",
		["side"] = coalition.side.RED,
	},
	[0] = {
		["name"] = "Russia",
		["side"] = coalition.side.RED,
	},
	[43] = {
		["name"] = "Serbia",
		["side"] = coalition.side.RED,
	},
	[19] = {
		["name"] = "South Ossetia",
		["side"] = coalition.side.RED,
	},
	[47] = {
		["name"] = "Syria",
		["side"] = coalition.side.RED,
	},
	[7] = {
		["name"] = "USAF Aggressors",
		["side"] = coalition.side.RED,
	},
	[17] = {
		["name"] = "Insurgents",
		["side"] = coalition.side.RED,
	},
	[71] = {
		["name"] = "Unknown-RED1",
		["side"] = coalition.side.RED,
	},
	[65] = {
		["name"] = "Unknown-RED2",
		["side"] = coalition.side.RED,
	},
	[72] = {
		["name"] = "Unknown-RED3",
		["side"] = coalition.side.RED,
	},
}

function coalition.getCountryCoalition(id)
	--print("get country coalition id: "..id)
	return coaltbl[id]["side"]
end
_G.coalition = coalition

local world = {}
world.event = {
	["S_EVENT_INVALID"]           = 0,
	["S_EVENT_SHOT"]              = 1,
	["S_EVENT_HIT"]               = 2,
	["S_EVENT_TAKEOFF"]           = 3,
	["S_EVENT_LAND"]              = 4,
	["S_EVENT_CRASH"]             = 5,
	["S_EVENT_EJECTION"]          = 6,
	["S_EVENT_REFUELING"]         = 7,
	["S_EVENT_DEAD"]              = 8,
	["S_EVENT_PILOT_DEAD"]        = 9,
	["S_EVENT_BASE_CAPTURED"]     = 10,
	["S_EVENT_MISSION_START"]     = 11,
	["S_EVENT_MISSION_END"]       = 12,
	["S_EVENT_TOOK_CONTROL"]      = 13,
	["S_EVENT_REFUELING_STOP"]    = 14,
	["S_EVENT_BIRTH"]             = 15,
	["S_EVENT_HUMAN_FAILURE"]     = 16,
	["S_EVENT_ENGINE_STARTUP"]    = 17,
	["S_EVENT_ENGINE_SHUTDOWN"]   = 18,
	["S_EVENT_PLAYER_ENTER_UNIT"] = 19,
	["S_EVENT_PLAYER_LEAVE_UNIT"] = 20,
	["S_EVENT_PLAYER_COMMENT"]    = 21,
	["S_EVENT_SHOOTING_START"]    = 22,
	["S_EVENT_SHOOTING_END"]      = 23,
	["S_EVENT_MAX"]               = 24,
}
function world.addEventHandler(handler)
end
_G.world = world

-- DCS Classes
--
local Object = class()
function Object:__init(name)
	self.name = name
end
Object.Category = {
	["UNIT"]    = 1,
	["WEAPON"]  = 2,
	["STATIC"]  = 3,
	["BASE"]    = 4,
	["SCENERY"] = 5,
	["CARGO"]   = 6,
}

function Object:isExist()
	return true
end

function Object:destroy()
end

function Object:getCategory()
end

function Object:getTypeName()
	return "F-15C"
end

function Object:getDesc()
end

function Object:hasAttribute(attribute)
end

function Object:getName()
	return self.name
end

function Object:getPoint()
end

function Object:getPosition()
end

function Object:getVelocity()
end

function Object:inAir()
end

function Object:getID()
	return 12
end
_G.Object = Object


local Coalition = class(Object)
function Coalition:__init(name)
	Object.__init(self, name)
end
function Coalition:getCoalition()
	return coalition.side.RED
end

function Coalition:getCountry()
	return 8
end
_G.Coalition = Coalition


local Unit = class(Coalition)
function Unit:__init(name)
	Coalition.__init(self, name)
end
Unit.Category = {
	["AIRPLANE"]    = 0,
	["HELICOPTER"]  = 1,
	["GROUND_UNIT"] = 2,
	["SHIP"]        = 3,
	["STRUCTURE"]   = 4,
}
Unit.RefuelingSystem = {
	["BOOM_AND_RECEPTACLE"] = 1,
	["PROBE_AND_DROGUE"]    = 2,
}

function Unit.getByName(name)
	return Unit(name)
end

function Unit:getLife()
	return 2
end

function Unit:getLife0()
	return 3
end

function Unit:getGroup()
	return Group("testgrp")
end

function Unit:getPlayerName()
	return self.name
end
_G.Unit = Unit

local StaticObject = class(Coalition)
StaticObject.Category = {
	["VOID"]    = 0,
	["UNIT"]    = 1,
	["WEAPON"]  = 2,
	["STATIC"]  = 3,
	["BASE"]    = 4,
	["SCENERY"] = 5,
	["CARGO"]   = 6,
}

function StaticObject.getByName(name)
	return StaticObject
end

function StaticObject:getLife()
	return 3
end
_G.StaticObject = StaticObject

local Group = class(Coalition)
function Group:__init(name)
	Coalition.__init(self, name)
end

function Group.getByName(name)
	return Group
end

function Group:getInitialSize()
	return 4
end

function Group:getSize()
	return 2
end

function Group:getUnit(num)
	return Unit("testunit")
end
_G.Group = Group

local missionCommands = {}
function missionCommands.addCommand(name, path, func, args)
end

function missionCommands.addSubMenu(name, path)
end

function missionCommands.removeItem(path)
end

function missionCommands.addCommandForCoalition(side, name, path, func, args)
end

function missionCommands.addSubMenuForCoalition(side, name, path)
end

function missionCommands.removeItemForCoalition(side, path)
end

function missionCommands.addCommandForGroup(id, name, path, func, args)
end

function missionCommands.addSubMenuForGroup(id, name, path)
end

function missionCommands.removeItemForGroup(id, path)
end
_G.missionCommands = missionCommands

local coord = {}
function coord.LOtoLL(pos)
	return 88.123, -63.456, pos.y
end

function coord.LLtoMGRS(lat, long)
	return {
		["UTMZone"] = "DD",
		["MGRSDigraph"] = "GJ",
		["Easting"] = 01234,
		["Northing"] = 56789,
	}
end
_G.coord = coord

local trigger = {}
trigger.action = {}

local msgbuffer  = ""
local enabletest = false
function trigger.action.setmsgbuffer(msg)
	msgbuffer = msg
end

function trigger.action.setassert(val)
	enabletest = val
end

function trigger.action.outTextForGroup(gid, msg, disptime, clear)
	if enabletest == true then
		assert(msg == msgbuffer, "generated output not as expected;\ngot '"..
			msg.."';\n expected '"..msgbuffer.."'")
	end
end
_G.trigger = trigger
