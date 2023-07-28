#!/usr/bin/lua

require("math")
math.randomseed(50)
require("dcttestlibs")
require("dct")
local enum   = require("dct.enum")
local uicmds = require("dct.ui.cmds")
local Mission = require("dct.libs.Mission")

-- create a player group
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
}, grp, "bobplayer")

local briefingtxt = "Package: #5170\n"..
			"IFF Codes: M1(50), M3(5170)\n"..
			"Target AO: 88°07.38'N 063°27.36'W (DUBLIN)\n"..
			"Briefing:\n"..
			"We have reason to believe there is"..
			" a fuel storage facility at 88°07.38'N 063°27.36'W,"..
			" East of Krasnodar-Center.\n\n"..
			"Primary Objectives: Destroy the fuel tanks embedded in "..
			"the ground at the facility.\n\n"..
			"Secondary Objectives: Destroy the white storage hangars.\n\n"..
			"Recommended Pilots: 2\n\n"..
			"Recommended Ordnance: Pilot discretion."

local assignedPilots = "Assigned Pilots:\nbobplayer (F/A-18C Hornet)"

local testcmds = {
	{
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Status ==\n"..
			"Friendly Force Str: Nominal\nEnemy Force Str: Nominal\n\n"..
			"Airbases:\n  Friendly: CVN-71 Theodore Roosevelt\n  "..
			"Friendly: Kutaisi\n  Friendly: Senaki-Kolkhi\n  Hostile: Krymsk\n\n"..
			"Current Active Air Missions:\n  None\n\n"..
			"Available missions:\n  "..
			"OCA:  1\n  SEAD:  2\n  STRIKE:  3\n\n"..
			"Recommended Mission Type: SEAD",
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONREQUEST,
			["value"]  = enum.missionType.STRIKE,
		},
		["assert"]     = true,
		["expected"]   = "Mission 5170 assigned, use F10 menu to "..
			"see this briefing again\n"..
			briefingtxt.."\n\n"..
			"BDA: 0% complete\n\n"..
			assignedPilots
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.THEATERSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "== Theater Status ==\n"..
			"Friendly Force Str: Nominal\nEnemy Force Str: Nominal\n\n"..
			"Airbases:\n  Friendly: CVN-71 Theodore Roosevelt\n  "..
			"Friendly: Kutaisi\n  Friendly: Senaki-Kolkhi\n  Hostile: Krymsk\n\n"..
			"Current Active Air Missions:\n  STRIKE:  1\n\n"..
			"Available missions:\n  "..
			"OCA:  1\n  SEAD:  2\n  STRIKE:  2\n\n"..
			"Recommended Mission Type: SEAD",
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONBRIEF,
		},
		["assert"]     = true,
		["expected"]   = briefingtxt,
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		},
		["assert"]     = true,
		["expected"]   = "Mission State: Preparing\n"..
			"Package: 5170\n"..
			"Timeout: 2016-06-21 12:30z (in 90 mins)\n"..
			"BDA: 0% complete\n\n"..
			assignedPilots
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONROLEX,
			["value"]  = 120,
		},
		["assert"]     = true,
		["expected"]   = "+2 mins added to mission timeout",
		--[[
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONCHECKIN,
		},
		["assert"]     = true,
		["expected"]   = "on-station received",
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONCHECKOUT,
		},
		["assert"]     = true,
		["expected"]   = "off-station received, vul time: 0",
		--]]
	}, {
		-- Test 2 min rolex and 5 min delay
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONSTATUS,
		},
		["modelTime"]  = 300,
		["assert"]     = true,
		["expected"]   = "Mission State: Preparing\n"..
			"Package: 5170\n"..
			"Timeout: 2016-06-21 12:32z (in 87 mins)\n"..
			"BDA: 0% complete\n\n"..
			assignedPilots
	}, {
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.MISSIONABORT,
			["value"]  = Mission.typeResult.ABORT,
		},
		["assert"]     = true,
		["expected"]   = "Mission 5170 aborted",
	}, {
		-- Allowed payload
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.CHECKPAYLOAD,
		},
		["ammo"] = {
			{
				["desc"] = {
					["displayName"] = "Cannon Shells",
					["category"] = Weapon.Category.SHELL,
				},
				["count"] = 600,
			}, {
				["desc"] = {
					["displayName"] = "AIM-9M",
					["typeName"] = "AIM_9",
					["category"] = Weapon.Category.MISSILE,
					["missileCategory"] = Weapon.MissileCategory.AAM,
				},
				["count"] = 2,
			}, {
				["desc"] = {
					["displayName"] = "AIM-120B",
					["typeName"] = "AIM_120",
					["category"] = Weapon.Category.MISSILE,
					["missileCategory"] = Weapon.MissileCategory.AAM,
				},
				["count"] = 4,
			}
		},
		["assert"]     = true,
		["expected"]   = "Valid loadout, you may depart. Good luck!\n\n"..
			"== Loadout Summary:\n"..
			"  AA cost: 20 / 20\n"..
			"  AG cost: 0 / 60\n"..
			"\n"..
			"== AA Weapons:\n"..
			"  AIM-9M\n"..
			"    ↳ 2 × unrestricted (0 pts)\n"..
			"  AIM-120B\n"..
			"    ↳ 4 × 5 pts = 20 pts",
	}, {
		-- Over limit with forbidden weapon
		["data"] = {
			["name"]   = grp:getName(),
			["type"]   = enum.uiRequestType.CHECKPAYLOAD,
		},
		["ammo"] = {
			{
				["desc"] = {
					["displayName"] = "RN-28",
					["typeName"] = "RN-28",
					["category"] = Weapon.Category.BOMB,
				},
				["count"] = 1,
			}
		},
		["assert"]     = true,
		["expected"]   = "You are over budget! Re-arm before departing, or "..
			"you will be punished!\n\n"..
			"== Loadout Summary:\n"..
			"  AA cost: 0 / 20\n"..
			"  AG cost: -- / 60\n"..
			"\n"..
			"== AG Weapons:\n"..
			"  RN-28\n"..
			"    ↳ Weapon cannot be used in this theater [!]",
	},
}

local function main()
	local modeltime = 50
	local theater = dct.Theater()

	dct.theater = theater
	dctstubs.setModelTime(modeltime)
	theater:exec(modeltime)
	theater:onEvent({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = unit1,
	})

	for _, v in ipairs(testcmds) do
		if v.modelTime ~= nil then
			dctstubs.setModelTime(v.modelTime)
		end
		if v.ammo ~= nil then
			unit1.ammo = v.ammo
		end
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
