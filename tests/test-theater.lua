#!/usr/bin/lua

require("os")
require("io")
local md5 = require("md5")
require("dcttestlibs")
require("dct")
local enum   = require("dct.enum")
local settings = dct.settings.server
settings.profile = true
local DEBUG = false

local events = {
	{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-1",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-2",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-3",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-4",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-5",
			["objtype"] = Object.Category.UNIT,
		},
	},{
		["id"] = world.event.S_EVENT_DEAD,
		["object"] = {
			["name"] = "Novorossiysk_NovoShipsinPort 1 SHIP 1-6",
			["objtype"] = Object.Category.UNIT,
		},
	},
}

local function copyfile(src, dest)
	local json = require("libs.json")
	local orig = io.open(src, "r")
	local save = io.open(dest, "w")
	save:write(json:encode_pretty(json:decode(orig:read("*a"))))
	orig:close()
	save:close()
end

local function main()
	local startdate = os.date("!*t")
	local playergrp = Group(4, {
		["id"] = 9,
		["name"] = "VMFA251 - Enfield 1-1",
		["coalition"] = coalition.side.BLUE,
		["exists"] = true,
	})
	local player1 = Unit({
		["name"]   = "player1",
		["exists"] = true,
		["desc"] = {
			["typeName"] = "FA-18C_hornet",
			["attributes"] = {},
		},
	}, playergrp, "bobplayer")

	local theater = dct.Theater()
	dct.theater = theater
	theater.startdate = startdate

	dctstubs.setModelTime(50)
	theater:exec(50)
	local expected = 35
	assert(dctcheck.spawngroups == expected,
		string.format("group spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawngroups))
	expected = 36
	assert(dctcheck.spawnstatics == expected,
		string.format("static spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawnstatics))

	-- kill off some units
	for _, eventdata in ipairs(events) do
		theater:onEvent(dctstubs.createEvent(eventdata, player1))
	end

	theater:export()
	local f = io.open(settings.statepath, "r")
	local sumorig = md5.sumhexa(f:read("*all"))
	f:close()
	if DEBUG == true then
		print("sumorig: "..tostring(sumorig))
		copyfile(settings.statepath, settings.statepath..".orig")
	end

	dct.Logger.getByName("Theater"):info("++++ create new theater +++++")

	dctstubs.setModelTime(0)
	local newtheater = dct.Theater()
	dct.theater = newtheater
	theater.startdate = startdate
	dctstubs.setModelTime(50)
	newtheater:exec(50)

	local name = "Test region_1_Abu Musa Ammo Dump"
	-- verify the units read in do not include the asset we killed off
	assert(newtheater:getAssetMgr():getAsset(name) == nil,
		"state saving has an issue, dead asset is alive: "..name)

	local playercnt = 0
	for _, asset in newtheater:getAssetMgr():iterate() do
		if asset.type == enum.assetType.PLAYER then
			playercnt = playercnt + 1
		end
	end
	assert(playercnt == 20, "Player asset creation broken")

	os.remove(settings.statepath)
	newtheater:export()
	f = io.open(settings.statepath, "r")
	local sumsave = md5.sumhexa(f:read("*all"))
	f:close()
	if DEBUG == true then
		print("sumsave: "..tostring(sumsave))
		copyfile(settings.statepath, settings.statepath..".new")
	end
	os.remove(settings.statepath)

	if DEBUG == true then
		print(" sumorig == sumsave: "..tostring(sumorig == sumsave))
		print("statepath: "..tostring(settings.statepath))
	end
	assert(newtheater.statef == true and sumorig == sumsave,
		"state saving didn't produce the same md5sum")

	-- finish a state and reload it
	theater:getTickets():loss(1, 5000)
	theater:export()

	assert(theater:getTickets():isComplete() == true,
		"theater was not completed")

	-- allow a chance to save a backup of the state
	theater:onEvent({ id = world.event.S_EVENT_MISSION_END })

	theater = dct.Theater()
	_G.dct.theater = theater
	theater:exec(50)

	assert(theater:getTickets():isComplete() == false,
		"theater was not regenerated after completion")

	return 0
end

os.exit(main())
