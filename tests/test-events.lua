#!/usr/bin/lua

require("dcttestlibs")
require("dct")
dct.settings.server.profile = false
dct.settings.server.debug   = false

local testcases = {
	[1] = {
		["event"] = {
			["id"] = world.event.S_EVENT_HIT,
			["object"] = {
				["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 1",
				["objtype"] = Object.Category.STATIC,
				["life"] = 1,
			},
		},
	},
	[2] = {
		["event"] = {
			["id"] = world.event.S_EVENT_DEAD,
			["object"] = {
				["name"] = "Test region_Abu Musa Ammo Dump 1 STRUCTURE 1",
				["objtype"] = Object.Category.STATIC,
			},
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
	local t = dct.Theater()
	local playergrp = Group(4, {
		["id"] = 15,
		["name"] = "Uzi 35",
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

	t:exec(50)
	for _, data in ipairs(testcases) do
		t:onEvent(createEvent(data.event, player1))
	end
	return 0
end

os.exit(main())
