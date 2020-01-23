#!/usr/bin/lua

require("dcttestlibs")

require("dct")
local enum   = require("dct.enum")
local uicmds = require("dct.ui.cmds")

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

local testcmds = {
	[1] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Threat Status ==\n  Sea:    medium\n"..
			"  Air:    parity\n  ELINT:  medium\n  SAM:    medium\n\n"..
			"== Current Active Air Missions ==\n  No Active Missions\n\n"..
			"Recommended Mission Type: STRIKE\n",
	},
	[2] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONREQUEST,
			["value"]  = enum.missionType.STRIKE,
		},
		["assert"]     = true,
		["expected"]   = "Mission STRIKE0085 assigned, use the F10 Menu "..
			"to see your briefing.",
	},
	[3] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Threat Status ==\n  Sea:    medium\n"..
			"  Air:    parity\n  ELINT:  medium\n  SAM:    medium\n\n"..
			"== Current Active Air Missions ==\n  STRIKE:   1\n\n"..
			"Recommended Mission Type: None\n",
	},
	[4] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		},
		["assert"]     = true,
		["expected"]   = "ID: STRIKE0085\nTarget AO: 88°07.2'N 063°27.6'W"..
			" (SEOUL)\nBriefing:\nGround units operating in Iran have"..
			" informed us of an Iranian Ammo Dump 88°07.2'N 063°27.6'W."..
			" Find and destroy the bunkers and the ordnance within.\n"..
			"    Tot: 2001-06-22 19:02:20z\n    \n"..
			"    Primary Objectives: Destroy the large, armoured bunker."..
			" It is heavily fortified, so accuracy is key.\n    \n"..
			"    Secondary Objectives: Destroy the two smaller, white"..
			" hangars.\n    \n"..
			"    Recommended Pilots: 2\n    \n"..
			"    Recommended Ordnance: Heavy ordnance required for bunker"..
			" targets, e.g. Mk-84s or PGM Variants.",
	},
	[5] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "ID: STRIKE0085\nTimeout: "..
			"2001-06-22 21:03:54z (in 297 mins)\nBDA: 0% complete\n",
	},
	[6] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONROLEX,
			["value"]  = 120,
		},
		["assert"]     = true,
		["expected"]   = "+2 mins added to mission timeout",
	},
	[7] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONCHECKIN,
		},
		["assert"]     = true,
		["expected"]   = "on-station received",
	},
	[8] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONCHECKOUT,
		},
		["assert"]     = true,
		["expected"]   = "off-station received, vul time: 0",
	},
	[9] = {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONABORT,
			["value"]  = "player requested",
		},
		["assert"]     = true,
		["expected"]   = "Mission STRIKE0085 aborted, player requested",
	},
}

local function main()
	local theater = dct.Theater()
	-- We need to send a birth event to populate the Theater.playergps table
	theater:onEvent({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = unit1,
	})

	for _, v in ipairs(testcmds) do
		trigger.action.setassert(v.assert)
		trigger.action.setmsgbuffer(v.expected)
		local cmd = uicmds[v.data.type](theater, v.data)
		cmd:execute(400)
	end
	trigger.action.setassert(false)

	local data = {
		["name"]   = grp:getName(),
		["type"]   = enum.uiRequestType.MISSIONREQUEST,
		["value"]  = enum.missionType.STRIKE,
	}

	for _, v in pairs(enum.missionType) do
		data.value = v
		for _, s in pairs(coalition.side) do
			data.side = s
			local cmd = uicmds[data.type](theater, data)
			cmd:execute(500)
		end
	end
	return 0
end

os.exit(main())
