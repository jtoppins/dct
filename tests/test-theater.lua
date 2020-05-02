#!/usr/bin/lua

require("os")
require("io")
local md5 = require("md5")
require("dcttestlibs")
require("dct")
local enum   = require("dct.enum")
local settings = _G.dct.settings

local events = {
	{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 1",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 2",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 3",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 4",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 5",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 6",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 7",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 8",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 9",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 10",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 11",
			["objtype"] = Object.Category.STATIC,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-1",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-2",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-3",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-4",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-5",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-6",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-7",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-8",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-9",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-10",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-11",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-12",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-13",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-14",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Test region_Abu Musa Ammo Dump 1 GROUND_UNIT 12-15",
			["objtype"] = Object.Category.UNIT,
		},
	},
}



local function createEvent(eventdata, player)
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
	event.time = 2345
	if event.id == world.event.S_EVENT_DEAD then
		event.initiator = objref
		objref.clife = 0
	elseif event.id == world.event.S_EVENT_HIT then
		event.initiator = player
		event.weapon = nil
		event.target = objref
		objref.clife = objref.clife - eventdata.object.life
	else
		assert(false, "other event types not supported: "..tostring(event.id))
	end
	return event
end


local function main()
	local playergrp = Group(4, {
		["id"] = 15,
		["name"] = "Uzi 41",
		["coalition"] = coalition.side.BLUE,
		["exists"] = true,
	})
	local player1 = Unit({
		["name"]   = "player1",
		["exists"] = true,
		["desc"] = {
			["typeName"] = "FA-18C_hornet",
		},
	}, playergrp, "bobplayer")

	local theater = dct.Theater()
	assert(dctcheck.spawngroups == 1, "group spawn broken")
	assert(dctcheck.spawnstatics == 11, "static spawn broken")

	local restriction =
		theater:getATORestrictions(coalition.side.BLUE, "A-10C")
	local validtbl = { ["BAI"] = 5, ["CAS"] = 1, ["STRIKE"] = 3,}
	for k, v in pairs(restriction) do
		assert(validtbl[k] == v, "ATO Restriction error")
	end

	-- kill off some units
	for _, eventdata in ipairs(events) do
		theater:onEvent(createEvent(eventdata, player1))
	end

	theater:export()
	local f = io.open(settings.statepath, "r")
	local sumorig = md5.sum(f:read("*all"))
	f:close()

	local newtheater = dct.Theater()
	local name = "Test region_1_Abu Musa Ammo Dump"
	-- verify the units read in do not include the asset we killed off
	assert(newtheater:getAssetMgr():getAsset(name) == nil,
		"state saving has an issue")

	-- attempt to get theater status
	newtheater:onEvent({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = player1,
	})

	local status = {
		["data"] = {
			["name"]   = playergrp:getName(),
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Threat Status ==\n  Sea:    medium\n"..
			"  Air:    parity\n  ELINT:  medium\n  SAM:    medium\n\n"..
			"== Current Active Air Missions ==\n  No Active Missions\n\n"..
			"Recommended Mission Type: CAP\n",
	}
	local uicmds = require("dct.ui.cmds")
	trigger.action.setassert(status.assert)
	trigger.action.setmsgbuffer(status.expected)
	local cmd = uicmds[status.data.type](newtheater, status.data)
	cmd:execute(400)

	newtheater:export()
	f = io.open(settings.statepath, "r")
	local sumsave = md5.sum(f:read("*all"))
	f:close()
	os.remove(settings.statepath)

	assert(newtheater.statef == true and sumorig == sumsave,
		"state saving didn't produce the same md5sum")
	return 0
end

os.exit(main())
