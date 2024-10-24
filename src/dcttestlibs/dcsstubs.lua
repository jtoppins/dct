--- SPDX-License-Identifier: LGPL-3.0
--
-- Provides DCS stubs for the mission scripting environment.

require("os")
local utils = require("libs.utils")

require("lfs")
lfs.dct_testdata = os.getenv("DCT_DATA_ROOT") or "."
function lfs.writedir()
	return lfs.dct_testdata..utils.sep
end

function lfs.tempdir()
	return utils.join_paths(lfs.dct_testdata, "mission")
end

function lfs.currentdir()
	return utils.join_paths(lfs.dct_testdata, "gamedir")
end

local libscheck = require("libs.check")
local class = require("libs.class")
local testlog = os.getenv("DCT_TEST_LOG") or
		lfs.dct_testdata..utils.sep.."dct_test.log"
local logfile = io.open(testlog, "a+")

local dctcheck = {}
dctcheck.spawngroups  = 0
dctcheck.spawnunits   = 0
dctcheck.spawnstatics = 0
_G.dctcheck = dctcheck

local dctstubs = {}
dctstubs.model_time = 0
dctstubs.schedfunctbl = {}
dctstubs.eventhandlers = {}

function dctstubs.createPlayer(playername)
	local grp = Group(4, {
		["id"] = 9,
		["name"] = "VMFA251 - Enfield 1-1",
		["coalition"] = coalition.side.BLUE,
		["exists"] = true,
	})

	local unit1 = Unit({
		["name"] = "pilot1",
		["exists"] = true,
		["desc"] = {
			["typeName"] = "FA-18C_hornet",
			["displayName"] = "F/A-18C Hornet",
			["attributes"] = {},
		},
	}, grp, playername or "bobplayer")

	return unit1, grp
end

function dctstubs.setModelTime(time)
	dctstubs.model_time = time
end

function dctstubs.addModelTime(time)
	dctstubs.model_time = dctstubs.model_time + time
end

function dctstubs.runSched()
	for func, data in pairs(dctstubs.schedfunctbl) do
		if dctstubs.model_time > data.time then
			data.time = func(data.arg, dctstubs.model_time)
			if not (data.time ~= nil and
			   type(data.time) == "number") then
				dctstubs.schedfunctbl[func] = nil
			end
		end
	end
end

function dctstubs.runEventHandlers(event)
	world.onEvent(event)
end

function dctstubs.fastForward(time, step)
	for _ = 1,time or 100,1 do
		dctstubs.runSched()
		dctstubs.addModelTime(step or 3)
	end
end

function dctstubs.createEvent(eventdata, player)
	local event = {}
	local objref

	if eventdata.object.objtype == Object.Category.UNIT then
		objref = Unit.getByName(eventdata.object.name)
	elseif eventdata.object.objtype == Object.Category.STATIC then
		objref = StaticObject.getByName(eventdata.object.name)
	elseif eventdata.object.objtype == Object.Category.GROUP then
		objref = Group.getByName(eventdata.object.name)
	else
		assert(false, "other object types not supported")
	end

	assert(objref, "objref is nil")
	event.id = eventdata.id
	event.time = dctstubs.model_time
	if event.id == world.event.S_EVENT_DEAD then
		event.initiator = objref
		objref.clife = 0
	elseif event.id == world.event.S_EVENT_HIT then
		event.initiator = player
		event.weapon = nil
		event.target = objref
		objref.clife = objref.clife - eventdata.object.life
	else
		assert(false, "other event types not supported: "..
			tostring(event.id))
	end
	return event
end

_G.dctstubs = dctstubs

-- DCS Singletons
--

local objectcat = {
	["UNIT"]    = 1,
	["WEAPON"]  = 2,
	["STATIC"]  = 3,
	["BASE"]    = 4,
	["SCENERY"] = 5,
	["CARGO"]   = 6,
	-- not actualy part of DCS
	["GROUP"] = 7,
}

local function readfile(path)
	local f = io.open(path)
	local t = f:read()
	f:close()
	return t
end

local env = {}
env.mission = utils.readlua(lfs.tempdir()..utils.sep.."mission", "mission")
env.mission.theatre = readfile(lfs.tempdir()..utils.sep.."theatre")
local dictkeys = utils.readlua(lfs.tempdir()..utils.sep..
	table.concat({"l10n", "DEFAULT", "dictionary"}, utils.sep), "dictionary")
function env.getValueDictByKey(s)
	local r = dictkeys[s]
	if r ~= nil then
		return r
	end
	return s
end

function env.warning(msg, _)
	logfile:write(os.date("%F %X ").."WARN    "..msg.."\n")
end
function env.info(msg, _)
	logfile:write(os.date("%F %X ").."INFO    "..msg.."\n")
end
function env.error(msg, _)
	logfile:write(os.date("%F %X ").."ERROR   "..msg.."\n")
end
_G.env = env

local timer = {}
function timer.getTime()
	return dctstubs.model_time
end
function timer.getTime0()
	--- 15:00:00 mission start time
	return 15*3600
end
function timer.getAbsTime()
	return timer.getTime() + timer.getTime0()
end

function timer.scheduleFunction(fn, arg, time)
	dctstubs.schedfunctbl[fn] = {["arg"] = arg, ["time"] = time}
	return fn
end
_G.timer = timer

local country = {}
country.id = {
	["RUSSIA"]                  = 0,
	["UKRAINE"]                 = 1,
	["USA"]                     = 2,
	["TURKEY"]                  = 3,
	["UK"]                      = 4,
	["FRANCE"]                  = 5,
	["GERMANY"]                 = 6,
	["AGGRESSORS"]              = 7,
	["CANADA"]                  = 8,
	["SPAIN"]                   = 9,
	["THE_NETHERLANDS"]         = 10,
	["BELGIUM"]                 = 11,
	["NORWAY"]                  = 12,
	["DENMARK"]                 = 13,
	["ISRAEL"]                  = 15,
	["GEORGIA"]                 = 16,
	["INSURGENTS"]              = 17,
	["ABKHAZIA"]                = 18,
	["SOUTH_OSETIA"]            = 19,
	["ITALY"]                   = 20,
	["AUSTRALIA"]               = 21,
	["SWITZERLAND"]             = 22,
	["AUSTRIA"]                 = 23,
	["BELARUS"]                 = 24,
	["BULGARIA"]                = 25,
	["CHEZH_REPUBLIC"]          = 26,
	["CHINA"]                   = 27,
	["CROATIA"]                 = 28,
	["EGYPT"]                   = 29,
	["FINLAND"]                 = 30,
	["GREECE"]                  = 31,
	["HUNGARY"]                 = 32,
	["INDIA"]                   = 33,
	["IRAN"]                    = 34,
	["IRAQ"]                    = 35,
	["JAPAN"]                   = 36,
	["KAZAKHSTAN"]              = 37,
	["NORTH_KOREA"]             = 38,
	["PAKISTAN"]                = 39,
	["POLAND"]                  = 40,
	["ROMANIA"]                 = 41,
	["SAUDI_ARABIA"]            = 42,
	["SERBIA"]                  = 43,
	["SLOVAKIA"]                = 44,
	["SOUTH_KOREA"]             = 45,
	["SWEDEN"]                  = 46,
	["SYRIA"]                   = 47,
	["YEMEN"]                   = 48,
	["VIETNAM"]                 = 49,
	["VENEZUELA"]               = 50,
	["TUNISIA"]                 = 51,
	["THAILAND"]                = 52,
	["SUDAN"]                   = 53,
	["PHILIPPINES"]             = 54,
	["MOROCCO"]                 = 55,
	["MEXICO"]                  = 56,
	["MALAYSIA"]                = 57,
	["LIBYA"]                   = 58,
	["JORDAN"]                  = 59,
	["INDONESIA"]               = 60,
	["HONDURAS"]                = 61,
	["ETHIOPIA"]                = 62,
	["CHILE"]                   = 63,
	["BRAZIL"]                  = 64,
	["BAHRAIN"]                 = 65,
	["THIRDREICH"]              = 66,
	["YUGOSLAVIA"]              = 67,
	["USSR"]                    = 68,
	["ITALIAN_SOCIAL_REPUBLIC"] = 69,
	["ALGERIA"]                 = 70,
	["KUWAIT"]                  = 71,
	["QATAR"]                   = 72,
	["OMAN"]                    = 73,
	["UNITED_ARAB_EMIRATES"]    = 74,
	["UNKNOWN_81"]              = 81,
}

country.name  = {}
country.names = {}
for k,v in pairs(country.id) do
	country.name[v] = k
	country.names[v] = string.gsub(k, "_", " ")
end
_G.country = country

local radio = {}
radio.modulation = {AM = 0, FM = 1}
_G.radio = radio

local Weapon = {}
Weapon.Category = {
	["SHELL"]   = 0,
	["MISSILE"] = 1,
	["ROCKET"]  = 2,
	["BOMB"]    = 3,
	["TORPEDO"] = 4,
}

Weapon.GuidanceType = {
	["INS"]               = 1,
	["IR"]                = 2,
	["RADAR_ACTIVE"]      = 3,
	["RADAR_SEMI_ACTIVE"] = 4,
	["RADAR_PASSIVE"]     = 5,
	["TV"]                = 6,
	["LASER"]             = 7,
	["TELE"]              = 8,
}

Weapon.MissileCategory = {
	["AAM"]       = 1,
	["SAM"]       = 2,
	["BM"]        = 3,
	["ANTI_SHIP"] = 4,
	["CRUISE"]    = 5,
	["OTHER"]     = 6
}

Weapon.WarheadType = {
	["AP"]            = 0,
	["HE"]            = 1,
	["SHAPED_CHARGE"] = 2,
}
_G.Weapon = Weapon

local AI = {}
AI.Task = {
	["OrbitPattern"]     = {
		["RACE_TRACK"] = "Race-Track",
		["CIRCLE"]     = "Circle",
	},
	["Designation"]      = {
		["NO"]         = "No",
		["WP"]         = "WP",
		["IR_POINTER"] = "IR-Pointer",
		["LASER"]      = "Laser",
		["AUTO"]       = "Auto",
	},
	["TurnMethod"]       = {
		["FLY_OVER_POINT"] = "Fly Over Point",
		["FIN_POINT"]      = "Fin Point",
	},
	["VehicleFormation"] = {
		["VEE"]           = "Vee",
		["ECHELON_RIGHT"] = "EchelonR",
		["OFF_ROAD"]      = "Off Road",
		["RANK"]          = "Rank",
		["ECHELON_LEFT"]  = "EchelonL",
		["ON_ROAD"]       = "On Road",
		["CONE"]          = "Cone",
		["DIAMOND"]       = "Diamond",
	},
	["AltitudeType"]     = {
		["RADIO"] = "RADIO",
		["BARO"]  = "BARO",
	},
	["WaypointType"]     = {
		["TAKEOFF"]             = "TakeOff",
		["TAKEOFF_PARKING"]     = "TakeOffParking",
		["TURNING_POINT"]       = "Turning Point",
		["TAKEOFF_PARKING_HOT"] = "TakeOffParkingHot",
		["LAND"]                = "Land",
	},
	["WeaponExpend"]     = {
		["QUARTER"] = "Quarter",
		["TWO"]     = "Two",
		["ONE"]     = "One",
		["FOUR"]    = "Four",
		["HALF"]    = "Half",
		["ALL"]     = "All",
	},
}

AI.Skill = {
	["PLAYER"]    = "Player",
	["CLIENT"]    = "Client",
	["AVERAGE"]   = "Average",
	["GOOD"]      = "Good",
	["HIGH"]      = "High",
	["EXCELLENT"] = "Excellent",
}

AI.Option = {
	["Air"] = {
		["id"] = {
			["NO_OPTION"]               = -1,
			["ROE"]                     = 0,
			["REACTION_ON_THREAT"]      = 1,
			["RADAR_USING"]             = 3,
			["FLARE_USING"]             = 4,
			["FORMATION"]               = 5,
			["RTB_ON_BINGO"]            = 6,
			["SILENCE"]                 = 7,
			["RTB_ON_OUT_OF_AMMO"]      = 10,
			["ECM_USING"]               = 13,
			["PROHIBIT_AA"]             = 14,
			["PROHIBIT_JETT"]           = 15,
			["PROHIBIT_AB"]             = 16,
			["PROHIBIT_AG"]             = 17,
			["MISSILE_ATTACK"]          = 18,
			["PROHIBIT_WP_PASS_REPORT"] = 19,
			["OPTION_RADIO_USAGE_CONTACT"] = 21,
			["OPTION_RADIO_USAGE_ENGAGE"] = 22,
			["OPTION_RADIO_USAGE_KILL"] = 23,
			-- OPTION_RADIO_* value: attribute list
			["JETT_TANKS_IF_EMPTY"]     = 25,
			["FORCED_ATTACK"]           = 26,
		},
		["val"] = {
			-- ROE Descriptions:
			-- WEAPON_FREE:
			--     AI will engage any enemy group it detects.
			--     Target prioritization is based based on the
			--     threat of the target.
			-- OPEN_FIRE_WEAPON_FREE:
			--     AI will engage any enemy group it detects,
			--     but will prioritize targets specified in the
			--     groups tasking.
			-- OPEN_FIRE:
			--     AI will engage only targets specified in its
			--     taskings.
			-- RETURN_FIRE:
			--     AI will only engage threats that shoot first.
			-- WEAPON_HOLD:
			--     AI will hold fire under all circumstances.
			["ROE"] = {
				["WEAPON_FREE"]           = 0,
				["OPEN_FIRE_WEAPON_FREE"] = 1,
				["OPEN_FIRE"]             = 2,
				["RETURN_FIRE"]           = 3,
				["WEAPON_HOLD"]           = 4,
			},
			["REACTION_ON_THREAT"] = {
				["NO_REACTION"]         = 0,
				["PASSIVE_DEFENCE"]     = 1,
				["EVADE_FIRE"]          = 2,
				["BYPASS_AND_ESCAPE"]   = 3,
				["ALLOW_ABORT_MISSION"] = 4,
			},
			["RADAR_USING"] = {
				["NEVER"]                  = 0,
				["FOR_ATTACK_ONLY"]        = 1,
				["FOR_SEARCH_IF_REQUIRED"] = 2,
				["FOR_CONTINUOUS_SEARCH"]  = 3,
			},

			-- NEVER:
			--     Chaff and Flares will not be used in any
			--     circumstances.
			-- AGAINST_FIRED_MISSILE:
			--     AI will only deploy chaff and flare if an
			--     incoming enemy missile is detected.
			-- WHEN_FLYING_IN_SAM_WEZ:
			--     AI will release chaff and/or flares as a
			--     preventative measure when inside a known
			--     enemy SAM threat zone or within weapons range
			--     of a known enemy aircraft armed with IR-homing
			--     missile. Default Setting.
			-- WHEN_FLYING_NEAR_ENEMIES:
			--     Unknown.
			["FLARE_USING"] = {
				["NEVER"]                    = 0,
				["AGAINST_FIRED_MISSILE"]    = 1,
				["WHEN_FLYING_IN_SAM_WEZ"]   = 2,
				["WHEN_FLYING_NEAR_ENEMIES"] = 3,
			},

			-- NEVER_USE:
			--     Disables the ability for AI to use their ECM.
			-- USE_IF_ONLY_LOCK_BY_RADAR:
			--     If the AI is actively being locked by an enemy
			--     radar they will enable their ECM jammer.
			-- USE_IF_DETECTED_LOCK_BY_RADAR:
			--     If the AI is being detected by a radar they will
			--     enable their ECM.
			-- ALWAYS_USE:
			--     AI will leave their ECM on all the time.
			["ECM_USING"] = {
				["NEVER_USE"]                     = 0,
				["USE_IF_ONLY_LOCK_BY_RADAR"]     = 1,
				["USE_IF_DETECTED_LOCK_BY_RADAR"] = 2,
				["ALWAYS_USE"]                    = 3,
			},

			-- Missile Attack option descriptsion:
			-- Max Range:
			--     AI will engage at the maximum range of the
			--     missile they intend to fire.
			-- NEZ Range:
			--     AI will engage once within the No Escape Zone
			--     for a given target.
			-- Halfway Rmax to NEZ:
			--     The AI will fire their missile halfway between
			--     the Rmax and No Escape Zone for the given
			--     target.
			-- Target threat estimated:
			--     AI will engage based on the possible threat
			--     the enemy target could provide. For example if
			--     the target is an F-15C the AI is likely to
			--     engage it at longer ranges than a C-130.
			-- Random Range:
			--     AI will first engage at a random distance
			--     between NEZ and Max range.
			["MISSILE_ATTACK"] = {
				["MAX_RANGE"]         = 0,
				["NEZ_RANGE"]         = 1,
				["HALF_WAY_RMAX_NEZ"] = 2,
				["TARGET_THREAT_EST"] = 3,
				["RANDOM_RANGE"]      = 4,
			},
		},
	},
	["Ground"] = {
		["id"] = {
			["NO_OPTION"]          = -1,
			["ROE"]                = 0,
			["FORMATION"]          = 5,
			["DISPERSE_ON_ATTACK"] = 8,
			["ALARM_STATE"]        = 9,
			["ENGAGE_AIR_WEAPONS"] = 20,
			["AC_ENGAGEMENT_RANGE_RESTRICTION"] = 24,
			["RESTRICT_AAA_MIN"]   = 27,
			["RESTRICT_TARGETS"]   = 28,
			["RESTRICT_AAA_MAX"]   = 29,
		},
		["val"] = {
			["ALARM_STATE"] = {
				["AUTO"]  = 0,
				["GREEN"] = 1,
				["RED"]   = 2,
			},
			["ROE"] = {
				["OPEN_FIRE"]   = 2,
				["RETURN_FIRE"] = 3,
				["WEAPON_HOLD"] = 4,
			},
			["RESTRICT_TARGETS"] = {
				["ANY"] = 0,
				["AIR"] = 1,
				["GND"] = 2,
			},
		},
	},
	["Naval"] = {
		["id"] = {
			["NO_OPTION"] = -1,
			["ROE"] = 0,
			["ALARM_STATE"] = 9,
		},
		["val"] = {
			["ROE"] = {
				["OPEN_FIRE"]   = 2,
				["RETURN_FIRE"] = 3,
				["WEAPON_HOLD"] = 4,
			},
			["ALARM_STATE"] = {
				["AUTO"]  = 0,
				["GREEN"] = 1,
				["RED"]   = 2,
			},
		},
	},
}
_G.AI = AI

local objdefaults = {
	["name"] = "obj1",
	["exists"] = false,
	["category"] = objectcat.UNIT,
	["desc"] = {
		["massEmpty"] = 34000,
		["riverCrossing"] = true,
		["maxSlopeAngle"] = 0.27000001072884,
		["RCS"] = 5,
		["box"] = {
			["min"] = {
				["y"] = 0.039917565882206,
				["x"] = -4.5607042312622,
				["z"] = -1.7571629285812,
			},
			["max"] = {
				["y"] = 3.610570192337,
				["x"] = 4.5179929733276,
				["z"] = 1.7558742761612,
			},
		},
		["speedMax"] = 18.055599212646,
		["life"] = 3,
		["attributes"] = {
			["SAM TR"] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			["NonArmoredUnits"] = true,
			["SAM SR"] = true,
			["Air Defence"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
		},
		["category"] = 2,
		["speedMaxOffRoad"] = 18.055599212646,
		["Kmax"] = 0.050000000745058,
		["typeName"] = "Tor 9A331",
		["displayName"] = "SAM SA-15 Tor 9A331",
	},
	["position"] = {
		["p"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["x"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["y"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["z"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
	},
	["vel"] = {["x"] = 1, ["y"] = 0, ["z"] = 1},
	["inair"] = false,
	["id"] = 123,
}

local objects = {}
for _,v in pairs(objectcat) do
	objects[v] = {}
end

local coalition = {}
coalition.side = {}
coalition.side.NEUTRAL = 0
coalition.side.RED     = 1
coalition.side.BLUE    = 2

function coalition.getAirbases(side)
	assert(side, "side must be provided")
	local tbl = {}
	for _, obj in pairs(objects[Object.Category.BASE]) do
		if side == obj.coalition then
			table.insert(tbl, obj)
		end
	end
	return tbl
end

function coalition.addGroup(cntryid, groupcat, groupdata)
	--print("new group: "..require("libs.json"):encode_pretty(groupdata))
	dctcheck.spawngroups = dctcheck.spawngroups + 1
	dctcheck.spawnunits = dctcheck.spawnunits + #(groupdata.units)
	groupdata.country = cntryid
	groupdata.groupCategory = groupcat
	groupdata.exists = true
	local grp = Group(#groupdata.units, groupdata)
	for _, unitdata in pairs(groupdata.units) do
		unitdata.exists = true
		Unit(unitdata, grp)
	end
	return grp
end

function coalition.addStaticObject(cntryid, groupdata)
	--print("new static: "..require("libs.json"):encode_pretty(groupdata))
	assert(groupdata.unitId == nil, "unitId field defined")
	dctcheck.spawnstatics = dctcheck.spawnstatics + 1
	groupdata.country = cntryid
	groupdata.exists = true
	StaticObject(groupdata)
end

function coalition.getCountryCoalition(id)
	local c
	for coa, tbl in pairs(env.mission.coalitions) do
		local found = utils.getkey(tbl, id)
		if found ~= nil then
			c = string.upper(coa)
			break
		end
	end
	return coalition.side[c]
end

function coalition.getGroups(side)
	assert(side, "side must be provided")
	local tbl = {}
	for _, obj in pairs(objects[Object.Category.GROUP]) do
		if side == obj.coalition then
			table.insert(tbl, obj)
		end
	end
	return tbl
end
_G.coalition = coalition

local world = {}
world.VolumeType = {
	["SEGMENT"] = 1,
	["BOX"]     = 2,
	["SPHERE"]  = 3,
	["PYRAMID"] = 4,
}
world.event = {
	S_EVENT_INVALID                      = 0,
	S_EVENT_SHOT                         = 1,
	S_EVENT_HIT                          = 2,
	S_EVENT_TAKEOFF                      = 3,
	S_EVENT_LAND                         = 4,
	S_EVENT_CRASH                        = 5,
	S_EVENT_EJECTION                     = 6,
	S_EVENT_REFUELING                    = 7,
	S_EVENT_DEAD                         = 8,
	S_EVENT_PILOT_DEAD                   = 9,
	S_EVENT_BASE_CAPTURED                = 10,
	S_EVENT_MISSION_START                = 11,
	S_EVENT_MISSION_END                  = 12,
	S_EVENT_TOOK_CONTROL                 = 13,
	S_EVENT_REFUELING_STOP               = 14,
	S_EVENT_BIRTH                        = 15,
	S_EVENT_HUMAN_FAILURE                = 16,
	S_EVENT_DETAILED_FAILURE             = 17,
	S_EVENT_ENGINE_SHUTDOWN              = 19,
	S_EVENT_ENGINE_STARTUP               = 18,
	S_EVENT_PLAYER_ENTER_UNIT            = 20,
	S_EVENT_PLAYER_LEAVE_UNIT            = 21,
	S_EVENT_PLAYER_COMMENT               = 22,
	S_EVENT_SHOOTING_START               = 23,
	S_EVENT_SHOOTING_END                 = 24,
	S_EVENT_MARK_ADDED                   = 25,
	S_EVENT_MARK_CHANGE                  = 26,
	S_EVENT_MARK_REMOVED                 = 27,
	S_EVENT_KILL                         = 28,
	S_EVENT_SCORE                        = 29,
	S_EVENT_UNIT_LOST                    = 30,
	S_EVENT_LANDING_AFTER_EJECTION       = 31,
	S_EVENT_PARATROOPER_LENDING          = 32,
	S_EVENT_DISCARD_CHAIR_AFTER_EJECTION = 33,
	S_EVENT_WEAPON_ADD                   = 34,
	S_EVENT_TRIGGER_ZONE                 = 35,
	S_EVENT_LANDING_QUALITY_MARK         = 36,
	S_EVENT_BDA                          = 37,
	S_EVENT_AI_ABORT_MISSION             = 38,
	S_EVENT_DAYNIGHT                     = 39,
	S_EVENT_FLIGHT_TIME                  = 40,
	S_EVENT_PLAYER_SELF_KILL_PILOT       = 41,
	S_EVENT_PLAYER_CAPUTRE_AIRFIELD      = 42,
	S_EVENT_EMERGENCY_LANDING            = 43,
	S_EVENT_UNIT_CREATE_TASK             = 44,
	S_EVENT_UNIT_DELETE_TASK             = 45,
	S_EVENT_MAX                          = 46,
}

function world.addEventHandler(obj)
	assert(type(obj.onEvent) == "function", "registering an object with "..
		"no .onEvent function")
	dctstubs.eventhandlers[obj] = true
end

function world.removeEventHandler(obj)
	dctstubs.eventhandlers[obj] = nil
end

function world.onEvent(event)
	for obj, _ in pairs(dctstubs.eventhandlers) do
		obj:onEvent(event)
	end
end

function world.getAirbases()
	local tbl = {}
	for _, obj in pairs(objects[Object.Category.BASE]) do
		table.insert(tbl, obj)
	end
	return tbl
end
function world.searchObjects()
end

_G.world = world

-- DCS Classes
--

local Controller = class()
function Controller:__init()
end

Controller.Detection = {
	["VISUAL"] = 1,
	["OPTIC"]  = 2,
	["RADAR"]  = 4,
	["IRST"]   = 8,
	["RWR"]    = 16,
	["DLINK"]  = 32,
}

function Controller:setTask(--[[task]])
end

function Controller:resetTask()
end

function Controller:pushTask(--[[task]])
end

function Controller:popTask()
end

function Controller:hasTask()
	return true
end

function Controller:setCommand(cmd)
	assert(cmd, "value error: cmd cannot be nil")
end

function Controller:setOption(id, value)
	assert(type(id) == "number", "value error: id must be a number")
	assert(value, "value error: value cannot be nil")
end

function Controller:setOnOff(value)
	assert(type(value) == "boolean", "value error: value must be a bool")
end

function Controller:setAltitude(--[[alt, keep, alttype]])
end

function Controller:setSpeed(--[[speed, keep]])
end

function Controller:knowTarget(--[[object, type, distance]])
end

function Controller:isTargetDetected(--[[object, ...<detection type>]])
	return false, false, 0, false, false, nil, nil
	-- detected, visible, lastTime, typeknown, distance,
	-- lastPos, lastVel
end

function Controller:getDetectedTargets(--[[...<detection type>]])
	return {}
end
_G.Controller = Controller

local Object = class()

function Object.printObjects()
	for k,v in pairs(objects) do
		for name, obj in pairs(v) do
			print("objects["..k.."]["..name.."] = "..tostring(obj))
		end
	end
end

function Object:__init(objdata)
	local data = objdata or {}
	for k,v in pairs(objdefaults) do
		self[k] = data[k]
		if self[k] == nil then
			self[k] = utils.deepcopy(v)
		end
	end
	objects[self.category][self.name] = self
end
Object.Category = objectcat
function Object:isExist()
	return self.exists
end

function Object:destroy()
	objects[self.category][self.name] = nil
end

function Object:getCategory()
	return self.category
end

function Object:getTypeName()
	return self.desc.typeName
end

function Object:getDesc()
	return self.desc
end

function Object:hasAttribute(attribute)
	return self.desc.attributes[attribute]
end

function Object:getName()
	return self.name
end

function Object:getPoint()
	local tbl = self
	if not self.position then
		tbl = objdefaults
	end
	return tbl.position.p
end

function Object:getPosition()
	return self.position
end

function Object:getVelocity()
	return self.vel
end

function Object:inAir()
	return self.inair
end

function Object:getID()
	return self.id
end
_G.Object = Object

local SceneryObject = class(Object)
function SceneryObject:__init(objdata)
	objdata.category = Object.Category.SCENERY
	Object.__init(self, objdata)
	self.clife = self.desc.life or 1
end

function SceneryObject:getLife()
	assert(type(self.id_) == "number", "id_ is not a number")
	return 10
end
_G.SceneryObject = SceneryObject

local Coalition = class(Object)
function Coalition:__init(objdata)
	Object.__init(self, objdata)
	self.coalition = objdata.coalition
	if self.coalition == nil then
		self.coalition = coalition.side.RED
	end

	self.country = objdata.country
	if self.country == nil then
		self.country = 18
	end
end
function Coalition:getCoalition()
	return self.coalition
end

function Coalition:getCountry()
	return self.country
end
_G.Coalition = Coalition

local airbase_desc_defaults = {
	["life"] = 3600,
	["attributes"] = {
		["Airfields"] = true,
	},
	["_origin"] = "",
	["category"] = 0,
	["typeName"] = "Anapa-Vityazevo",
	["displayName"] = "Anapa-Vityazevo",
}

local Airbase = class(Coalition)
function Airbase:__init(objdata)
	objdata.category = Object.Category.BASE
	Coalition.__init(self, objdata)
	self.callsign = objdata.callsign
	self.parking = objdata.parking
	self.silenceATC = false
	self.desc = utils.deepcopy(airbase_desc_defaults)
	self.desc.typeName = self.name
	self.desc.displayName = self.name
	if objdata.airbaseCategory == nil then
		self.desc.category = Airbase.Category.AIRDROME
	else
		self.desc.category = objdata.airbaseCategory
		self.airbaseCategory = nil
	end

	self.group = nil
	self.Category = nil
	self.getByName = nil
end
Airbase.Category = {
	["AIRDROME"] = 0,
	["HELIPAD"]  = 1,
	["SHIP"]     = 2,
}

function Airbase.getByName(name)
	return objects[Object.Category.BASE][name]
end

function Airbase:getParking(_ --[[available]])
	return self.parking
end

function Airbase:getRunways()
	return {
		{
			["course"] = -1.597741484642,
			["Name"] = 8,
			["position"] = {
				["y"] = 952.94458007813,
				["x"] = -360507.1875,
				["z"] = -75590.0703125,
			},
			["length"] = 1859.3155517578,
			["width"] = 60,
		}, {
			["course"] = -2.5331676006317,
			["Name"] = 26,
			["position"] = {
				["y"] = 952.94458007813,
				["x"] = -359739.875,
				["z"] = -75289.5078125,
			},
			["length"] = 1859.3155517578,
			["width"] = 60,
		},
	}
end

function Airbase:getCallsign()
	return self.callsign
end

function Airbase:getUnit(num)
	if self.group == nil then
		return nil
	end
	return self.group:getUnit(num)
end

function Airbase:_addGroup(obj)
	assert(obj.isa(Group), "not a Group object")
	self.group = obj
end

function Airbase:getRadioSilentMode()
	return self.silenceATC
end

function Airbase:setRadioSilentMode(state)
	self.silenceATC = state
end

function Airbase:autoCapture(state)
	self.autocapture = state
end

function Airbase:setCoalition(coa)
	self.coalition = coa
end
_G.Airbase = Airbase


local Unit = class(Coalition)
function Unit:__init(objdata, group, pname)
	objdata.category = Object.Category.UNIT
	Coalition.__init(self, objdata)
	self.clife = self.desc.life
	self.group = group
	self.ammo = objdata.ammo
	if group ~= nil then
		group:_addUnit(self)
	end
	self.pname = pname
	objdata.unitId = self:getID()
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
	return objects[Object.Category.UNIT][name]
end

function Unit.getDescByName(--[[typename]])
	return objdefaults.desc
end

function Unit:getLife()
	return self.clife
end

function Unit:getLife0()
	return self.desc.life
end

function Unit:getGroup()
	return self.group
end

function Unit:getPlayerName()
	return self.pname
end

function Unit:getController()
	return Controller()
end

function Unit:getCallsign()
	return "foo"
end

function Unit:getAmmo()
	return self.ammo
end

function Unit:getRadar()
	return false, nil
end

function Unit:enableEmission(onoff)
	assert(type(onoff) == "boolean", "must be of type bool")
end
_G.Unit = Unit

local StaticObject = class(Coalition)
function StaticObject:__init(objdata)
	objdata.category = Object.Category.STATIC
	Coalition.__init(self, objdata)
	self.clife = self.desc.life
	objdata.unitId = self:getID()
end

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
	return objects[Object.Category.STATIC][name]
end

function StaticObject:getLife()
	return self.clife
end

function StaticObject:destroy()
	dctcheck.spawnstatics = dctcheck.spawnstatics - 1
	Object.destroy(self)
end
_G.StaticObject = StaticObject

local Group = class(Coalition)
function Group:__init(unitcnt, objdata)
	objdata.category = Object.Category.GROUP
	Coalition.__init(self, objdata)
	self.units = {}
	self.unitcnt = unitcnt
	self.groupCategory = objdata.groupCategory
	if self.groupCategory == nil then
		self.groupCategory = Unit.Category.AIRPLANE
	end
	self.desc = nil
	self.getTypeName = nil
	self.getDesc = nil
	self.hasAttribute = nil
	self.position = nil
	self.getPoint = nil
	self.getPosition = nil
	self.vel = nil
	self.getVelocity = nil
	self.inair = nil
	self.inAir = nil
	objdata.groupId = self:getID()
end

Group.Category = {
	AIRPLANE   = 0,
	HELICOPTER = 1,
	GROUND     = 2,
	SHIP       = 3,
	TRAIN      = 4,
}

function Group.getByName(name)
	return objects[Object.Category.GROUP][name]
end

function Group:destroy()
	for _, unit in pairs(self.units) do
		unit:destroy()
	end
	dctcheck.spawngroups = dctcheck.spawngroups - 1
	Object.destroy(self)
end

function Group:getCategory()
	return self.groupCategory
end

function Group:getInitialSize()
	return self.unitcnt
end

function Group:getSize()
	return #self.units
end

function Group:getUnit(num)
	return self.units[num]
end

function Group:getUnits()
	return self.units
end

function Group:_addUnit(obj)
	table.insert(self.units, obj)
end

function Group:getController()
	return Controller()
end

function Group:enableEmission(onoff)
	assert(type(onoff) == "boolean", "must be of type bool")
end
_G.Group = Group

local groupmenus = {}
local missionCommands = {}
function missionCommands.addCommand(_, _, _, _)
end

function missionCommands.addSubMenu(_, _)
end

function missionCommands.removeItem(_)
end

function missionCommands.addCommandForCoalition(_, _, _, _, _)
end

function missionCommands.addSubMenuForCoalition(_, _, _)
end

function missionCommands.removeItemForCoalition(_, _)
end

local function addGroupItem(gid, title, path, value)
	if groupmenus[gid] == nil then
		groupmenus[gid] = {}
	end

	if path == nil then
		path = {}
	end

	local ptbl = groupmenus[gid]
	for _, val in ipairs(path) do
		ptbl = ptbl[val]
	end
	ptbl[title] = value
	local npath = utils.deepcopy(path)
	table.insert(npath, title)
	return npath
end

function missionCommands.addCommandForGroup(gid, title, path)
--[[, handler, data]]
	return addGroupItem(gid, title, path, true)
end

function missionCommands.addSubMenuForGroup(gid, title, path)
	return addGroupItem(gid, title, path, {})
end

function missionCommands.removeItemForGroup(gid, path)
	if groupmenus[gid] == nil then
		return
	end

	if path == nil then
		groupmenus[gid] = {}
		return
	end

	local ptbl = groupmenus[gid]
	for i = 1, (#path - 1) do
		ptbl = ptbl[path[i]]
	end
	ptbl[path[#path]] = nil
end

local function dfs_print_menu(root, depth)
	local s = ""
	if type(root) ~= "table" then
		return s
	end

	local indent = string.rep(" ", depth*4)
	for key, value in pairs(root) do
		s = s..string.format("%s- %s\n", indent, key)..
			dfs_print_menu(value, depth + 1)
	end
	return s
end

function missionCommands.printGroupMenu(gid)
	return string.format("Group (%d):\n", gid)..
		dfs_print_menu(groupmenus[gid] or {}, 0)
end
_G.missionCommands = missionCommands

local coord = {}
function coord.LOtoLL(pos)
	return 88.123, -63.456, pos.y
end

function coord.LLtoLO(lat, long, alt)
	return {
		["x"] = 1000*lat/2,
		["y"] = alt,
		["z"] = 1000*long/2
	}
end

function coord.LLtoMGRS(_, _)
	return {
		["UTMZone"] = "DD",
		["MGRSDigraph"] = "GJ",
		["Easting"] = 01234,
		["Northing"] = 56789,
	}
end
_G.coord = coord

local gblflagtbl = {}
local trigger = {}
trigger.action = {}

local chkbuffer  = ""
local msgbuffer  = ""

local scope = {
	["ALL"]     = -1,
	["NEUTRAL"] = 0,
	["RED"]     = 1,
	["BLUE"]    = 2,
}

function trigger.action.setmsgbuffer(msg)
	chkbuffer = msg
end

function trigger.action.chkmsgbuffer()
	assert(msgbuffer == chkbuffer,
	       "generated output not as expected;\ngot '"..
	       msgbuffer.."';\n expected '"..chkbuffer.."'")
end

function trigger.action.outTextForGroup(grpid, msg, time, bool)
	libscheck.number(grpid)
	libscheck.string(msg)
	libscheck.number(time)
	libscheck.bool(bool)
	msgbuffer = msg
	logfile:write(os.date("%F %X ")..
		string.format("GRPMSG  %d;%s\n", grpid, msg))
end

function trigger.action.markToAll(id, msg, pos)
	libscheck.number(id)
	libscheck.string(msg)
	libscheck.table(pos)

	logfile:write(os.date("%F %X ")..string.format("MARKA   %d;%s\n",
						       id, msg))
end

function trigger.action.markToGroup(id, msg, pos, grpid)
	libscheck.number(id)
	libscheck.string(msg)
	libscheck.table(pos)
	libscheck.number(grpid)

	logfile:write(os.date("%F %X ")..string.format("MARKG   %d;%s\n",
						       id, msg))
end

function trigger.action.markToCoalition(id, msg, pos, coa)
	libscheck.number(id)
	libscheck.string(msg)
	libscheck.table(pos)
	libscheck.tblkey(coa, coalition.side, "coalition.side")

	logfile:write(os.date("%F %X ")..string.format("MARKC   %d;%s\n",
						       id, msg))
end

local function check_common_args(coa, id, color, linetype)
	libscheck.tblkey(coa, scope, "coalition.side")
	libscheck.number(id)
	libscheck.table(color)
	libscheck.number(linetype)
end

function trigger.action.lineToAll(coa, id, startpt, endpt, color, linetype)
	libscheck.table(startpt)
	libscheck.table(endpt)
	check_common_args(coa, id, color, linetype)
end

function trigger.action.circleToAll(coa, id, center, radius, color,
		fillcolor, linetype)
	libscheck.table(center)
	libscheck.table(fillcolor)
	libscheck.number(radius)
	check_common_args(coa, id, color, linetype)
end

function trigger.action.rectToAll(coa, id, startpt, endpt, color,
		fillcolor, linetype)
	libscheck.table(startpt)
	libscheck.table(endpt)
	libscheck.table(fillcolor)
	check_common_args(coa, id, color, linetype)
end

function trigger.action.quadToAll(coa, id, pt1, pt2, pt3, pt4, color,
		fillcolor, linetype)
	libscheck.table(pt1)
	libscheck.table(pt2)
	libscheck.table(pt3)
	libscheck.table(pt4)
	libscheck.table(fillcolor)
	check_common_args(coa, id, color, linetype)
end

function trigger.action.textToAll(coa, id, pt, color, fillcolor, fontsize)
	libscheck.table(pt)
	libscheck.table(fillcolor)
	check_common_args(coa, id, color, fontsize)
end

function trigger.action.arrowToAll(coa, id, startpt, endpt, color, fillcolor,
		linetype)
	libscheck.table(startpt)
	libscheck.table(endpt)
	libscheck.table(fillcolor)
	check_common_args(coa, id, color, linetype)
end

function trigger.action.removeMark(id)
	libscheck.number(id)
end

function trigger.action.setUserFlag(flagname, value)
	gblflagtbl[flagname] = tonumber(value)
end

trigger.misc = {}
function trigger.misc.getUserFlag(flagname)
	local val = gblflagtbl[flagname] or 0
	return val
end
_G.trigger = trigger

local land = {}
land.SurfaceType = {
	["LAND"]          = 1,
	["SHALLOW_WATER"] = 2,
	["WATER"]         = 3,
	["ROAD"]          = 4,
	["RUNWAY"]        = 5,
}

function land.getHeight(vec2)
	assert(vec2.x)
	assert(vec2.y)
	return 10
end

function land.getSurfaceHeightWithSeabed(vec2)
	assert(vec2.x)
	assert(vec2.y)
	return 10, 0
end

function land.getSurfaceType(--[[vec2]])
	return land.SurfaceType.LAND
end
_G.land = land

local atmosphere = {}
function atmosphere.getWind(_ --[[point]])
	return { y = 0, x = 2.17, z = 3.058 }
end

function atmosphere.getWindWithTurbulence(_ --[[point]])
	return { y = 0.0336, 2.17, z = 3.058 }
end

function atmosphere.getTemperatureAndPressure(_ --[[point]])
	return 293.15, 101325
end
_G.atmosphere = atmosphere

local net = {}
function net.dostring_in(context, code)
	logfile:write(os.date("%F %X ")..
		string.format("NET_DOSTRING context(%s):code(%s)\n",
			context, code))
end
_G.net = net
