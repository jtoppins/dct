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
function world.addEventHandler(handler)
end
_G.world = world

-- DCS Classes
--
local Object = class()
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
end

function Object:getDesc()
end

function Object:hasAttribute(attribute)
end

function Object:getName()
end

function Object:getPoint()
end

function Object:getPosition()
end

function Object:getVelocity()
end

function Object:inAir()
end
_G.Object = Object


local Coalition = class(Object)
function Coalition:getCoalition()
	return coalition.side.RED
end

function Coalition:getCountry()
	return 0
end
_G.Coalition = Coalition


local Unit = class(Coalition)
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
	return Unit
end

function Unit:getLife()
	return 2
end

function Unit:getLife0()
	return 3
end

function Unit:getGroup()
	return Group
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
function Group.getByName(name)
	return Group
end

function Group:getInitialSize()
	return 4
end

function Group:getSize()
	return 2
end
_G.Group = Group
