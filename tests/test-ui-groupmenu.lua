#!/usr/bin/lua

require("dcttestlibs")
require("dct")

-- create a player group
local grp = Group(4, {
	["id"] = 12,
	["name"] = "Uzi 11",
	["coalition"] = coalition.side.BLUE,
	["exists"] = true,
})

local unit1 = Unit({
	["name"] = "pilot1",
	["exists"] = true,
	["desc"] = {
		["typeName"] = "FA-18C_hornet",
	},
}, grp, "bobplayer")

-- Since groupmenu is added by the Theater, we just get a Theater
-- instance and then cook up an event to call the theater DCS
-- event handler with.

local testcmds = {
	[1] = {
		["event"] = {
			["id"]        = world.event.S_EVENT_BIRTH,
			["initiator"] = unit1,
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
	return 0
end

os.exit(main())
