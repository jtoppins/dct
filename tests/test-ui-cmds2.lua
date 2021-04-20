#!/usr/bin/lua

require("math")
math.randomseed(50)
require("dcttestlibs")
require("dct")
local enum = require("dct.enum")

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
		["attributes"] = {},
	},
}, grp, "bobplayer")

local testcmds = {
	[1] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		},
		["assert"]     = true,
		["expected"]   = "",
	},
	[2] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONREQUEST,
			["value"]  = enum.missionType.STRIKE,
		},
		["assert"]     = true,
		["expected"]   = "F10 request already pending, please wait.",
	},
	[3] = {
		["data"] = nil,
		["assert"]     = true,
		["expected"]   = "F10 request already pending, please wait.",
	},
}

local function main()
	local theater = dct.Theater()
	_G.dct.theater = theater
	theater:exec(50)
	-- We need to send a birth event to populate the Theater.playergps table
	theater:onEvent({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = unit1,
	})

	for _, v in ipairs(testcmds) do
		trigger.action.setassert(v.assert)
		trigger.action.setmsgbuffer(v.expected)
		dct.Theater.playerRequest(v.data)
	end
	return 0
end

os.exit(main())
