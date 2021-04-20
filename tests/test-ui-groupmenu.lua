#!/usr/bin/lua

require("dcttestlibs")
require("dct")

-- create a player group
local grp = Group(4, {
	["id"] = 26971,
	["name"] = "99thFS Uzi 11",
	["coalition"] = coalition.side.BLUE,
	["exists"] = true,
})

local unit1 = Unit({
	["name"] = "pilot1",
	["exists"] = true,
	["desc"] = {
		["typeName"] = "FA-18C_hornet",
		["attributes"] = {
			["Airplane"] = true,
		},
	},
}, grp, "bobplayer")

local grp2 = Group(1, {
	["id"] = 87507,
	["name"] = "Uzi 42",
	["coalition"] = coalition.side.BLUE,
	["exists"] = true,
})

local unit2 = Unit({
	["name"] = "pilot2",
	["exists"] = true,
	["desc"] = {
		["typeName"] = "FA-18C_hornet",
		["attributes"] = {
			["Airplane"] = true,
		},
	},
}, grp2, "tomplayer")


-- Since groupmenu is added by the Theater, we just get a Theater
-- instance and then cook up an event to call the theater DCS
-- event handler with.

local testcmds = {
	{
		["event"] = {
			["id"]        = world.event.S_EVENT_BIRTH,
			["initiator"] = unit1,
		},
		["assert"] = true,
		["expect"] = "Please read the loadout limits in the briefing"..
			" and use the F10 Menu to validate your loadout before"..
			" departing.",
	}, {
		["event"] = {
			["id"]        = world.event.S_EVENT_BIRTH,
			["initiator"] = unit2,
		},
		["assert"] = true,
		["expect"] = "Please read the loadout limits in the briefing"..
			" and use the F10 Menu to validate your loadout before"..
			" departing.",
	},
}

local function main()
	local theater = dct.Theater()
	_G.dct.theater = theater
	theater:exec(50)
	for _, data in ipairs(testcmds) do
		trigger.action.setmsgbuffer(data.expect)
		theater:onEvent(data.event)
		trigger.action.chkmsgbuffer()
	end

	local uzi11 = theater:getAssetMgr():getAsset("99thFS Uzi 11")
	local uzi42 = theater:getAssetMgr():getAsset("Uzi 42")

	local enum = require("dct.enum")
	assert(uzi11.payloadlimits[enum.weaponCategory.AG] == 20,
		"uzi11 doesn't have the expected AG payload limit")
	assert(uzi42.payloadlimits[enum.weaponCategory.AG] == 2000,
		"uzi42 doesn't have the expected AG payload limit")
	return 0
end

os.exit(main())
