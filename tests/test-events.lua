#!/usr/bin/lua

require("dcttestlibs")
require("dct")

local testcases = {
	[1] = {
		["event"] = {
			["id"] = world.event.S_EVENT_HIT,
			["object"] = {
				["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-1",
				["objtype"] = Object.Category.UNIT,
				["life"] = 1,
			},
		},
	},
	[2] = {
		["event"] = {
			["id"] = world.event.S_EVENT_DEAD,
			["object"] = {
				["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-2",
				["objtype"] = Object.Category.UNIT,
			},
		},
	},
}

local function main()
	local playergrp = Group(4, {
		["id"] = 15,
		["name"] = "99thFS Uzi 34",
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

	dct.init()
	dctstubs.setModelTime(50)
	dctstubs.runSched()

	local expected = 35
	assert(dctcheck.spawngroups == expected,
		string.format("group spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawngroups))
	expected = 36
	assert(dctcheck.spawnstatics == expected,
		string.format("static spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawnstatics))

	for _, data in ipairs(testcases) do
		dctstubs.runEventHandlers(dctstubs.createEvent(data.event,
							       player1))
	end
	return 0
end

os.exit(main())
