#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local enum   = require("dct.enum")
local uicmds = require("dct.ui.cmds")

local gid  = 26971
local name = "Uzi 11"
local side = coalition.side.BLUE
local unitType = "FA-18C_hornet"

local testcmds = {
	[1] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONREQUEST,
			["value"]  = enum.missionType.STRIKE,
		},
		["expected"] = "Mission A1234 assigned, see briefing for details",
	},
	[2] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Threat Status ==\n  Sea:    medium\n"..
			"  Air:    parity\n  ELINT:  medium\n  SAM:    medium\n\n"..
			"== Current Active Air Missions ==\n  CAP:  2\n\n"..
			"Recommended Mission Type: STRIKE\n",
	},
	[3] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		},
		["assert"]     = true,
		["expected"]   = "ID: A1234\nTarget: 88°07.38'N 063°27.36'W"..
			" (test-callsign)\nDescription:\nTODO description",
	},
	[4] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		},
		["assert"]     = false,
	},
	[5] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONROLEX,
			["value"]  = 120,
		},
		["assert"]     = true,
		["expected"]   = "+2 mins added to mission timeout",
	},
	[6] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONCHECKIN,
		},
		["assert"]     = true,
		["expected"]   = "on-station received",
	},
	[7] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONCHECKOUT,
		},
		["assert"]     = true,
		["expected"]   = "off-station received",
	},
	[8] = {
		["data"] = {
			["id"]     = gid,
			["name"]   = name,
			["side"]   = side,
			["actype"] = unitType,
			["type"]   = enum.uiRequestType.MISSIONABORT,
		},
		["assert"]     = true,
		["expected"]   = "Mission A1234 aborted",
	},
}

local function main()
	local theater = dct.Theater.getInstance()
	for _, v in ipairs(testcmds) do
		trigger.action.setassert(v.assert)
		trigger.action.setmsgbuffer(v.expected)
		local cmd = uicmds[v.data.type](theater, v.data)
		cmd:execute(400)
	end
	trigger.action.setassert(false)

	local data = {
		["id"]     = gid,
		["name"]   = name,
		["side"]   = side,
		["actype"] = unitType,
		["type"]   = enum.uiRequestType.MISSIONREQUEST,
		["value"]  = enum.missionType.STRIKE,
	}

	for _, v in pairs(enum.missionType) do
		data.value = v
		for _, side in pairs(coalition.side) do
			data.side = side
			local cmd = uicmds[data.type](theater, data)
			cmd:execute(500)
		end
	end
	return 0
end

os.exit(main())
