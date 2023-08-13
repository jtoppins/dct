#!/usr/bin/lua

math.randomseed(50)
require("dcttestlibs")
dofile(os.getenv("DCT_DATA_ROOT").."/../mission/dct-mission-init.lua")
local dctenum = require("dct.enum")
local uirequest = require("dct.ui.request")

local unit1, grp = dctstubs.createPlayer()
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

local function simulate_mark_edit(theater, player)
	local scratchpad = theater:getSystem("dct.systems.scratchpad")
	local data = scratchpad:get(51)
	local editmark = {}
	editmark.id = world.event.S_EVENT_MARK_CHANGE
	editmark.idx = data.mark.id
	editmark.initiator = unit1
	editmark.coalition = player.owner
	editmark.groupID = player:getDescKey("groupId")
	editmark.text = "3458"
	editmark.pos = {1, 2, 3}

	dctstubs.runEventHandlers(editmark)
end

local testcmds = {
	{
		["data"] = {
			["callback"] = uirequest.scratchpad_set,
		},
		["expected"] = "Look on F10 MAP for user mark with contents \""..
			"edit me\"\n Edit body with your scratchpad "..
			"information. Click off the mark when finished. "..
			"The mark will automatically be deleted.",
		["test"] = simulate_mark_edit,
	}, {
		["data"] = {
			["callback"] = uirequest.scratchpad_get,
		},
		["expected"] = "Scratch Pad: 3458",
	}, {
		-- Allowed payload
		["data"] = {
			["callback"] = uirequest.checkpayload,
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
		["expected"]   = "Valid loadout, you may depart. Good luck!\n\n"..
			"== Loadout Summary:\n"..
			"  GUN cost: 0 / 4999\n"..
			"  AA cost: 20 / 20\n"..
			"  AG cost: 0 / 60\n"..
			"\n"..
			"== GUN Weapons:\n"..
			"  Cannon Shells\n"..
			"    ↳ 600 × unrestricted (0 pts)\n"..
			"\n"..
			"== AA Weapons:\n"..
			"  AIM-9M\n"..
			"    ↳ 2 × unrestricted (0 pts)\n"..
			"  AIM-120B\n"..
			"    ↳ 4 × 5 pts = 20 pts",
	}, {
		-- Over limit with forbidden weapon
		["data"] = {
			["callback"] = uirequest.checkpayload,
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
		["expected"]   = "You are over budget! Re-arm before departing, or "..
			"you will be punished!\n\n"..
			"== Loadout Summary:\n"..
			"  GUN cost: 0 / 4999\n"..
			"  AA cost: 0 / 20\n"..
			"  AG cost: -- / 60\n"..
			"\n"..
			"== AG Weapons:\n"..
			"  RN-28\n"..
			"    ↳ Weapon cannot be used in this theater [!]",
	}, {
		["data"] = {
			["callback"] = uirequest.mission_request,
			["value"]  = dctenum.missionType.STRIKE,
		},
		["expected"]   = "Mission 5170 assigned, use F10 menu to "..
			"see this briefing again\n"..
			briefingtxt.."\n\n"..
			"BDA: 0% complete\n\n"..
			assignedPilots
	}, {
		["data"] = {
			["callback"] = uirequest.theater_status,
		},
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
			["callback"] = uirequest.mission_brief,
		},
		["expected"]   = briefingtxt,
	}, {
		["data"] = {
			["callback"] = uirequest.mission_status,
		},
		["expected"]   = "Mission State: Preparing\n"..
			"Package: 5170\n"..
			"Timeout: 2016-06-21 12:30z (in 90 mins)\n"..
			"BDA: 0% complete\n\n"..
			assignedPilots
	}, {
		["data"] = {
			["callback"] = uirequest.mission_leave,
		},
		["expected"]   = "Mission 5170 aborted",
	},
}

local function main()
	local theater = dct.theater
	dctstubs.setModelTime(50)
	dctstubs.fastForward(50, 30)

	local expected = 35
	assert(dctcheck.spawngroups == expected,
		string.format("group spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawngroups))
	expected = 36
	assert(dctcheck.spawnstatics == expected,
		string.format("static spawn broken; expected(%d), got(%d)",
		expected, dctcheck.spawnstatics))

	local player = theater:getAssetMgr():getAsset(grp.name)

	-- birth player
	theater:onEvent({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = unit1,
	})
	dctstubs.fastForward(10, 20)

	for _, v in ipairs(testcmds) do
		if v.ammo ~= nil then
			unit1.ammo = v.ammo
		end
		v.data.name = grp:getName()
		trigger.action.setmsgbuffer(v.expected)
		uirequest.defer_request(player, v.data)
		dctstubs.fastForward(10, 20)
		trigger.action.chkmsgbuffer()
		if type(v.test) == "function" then
			v.test(theater, player)
			dctstubs.fastForward(10, 30)
		end
	end
	os.remove(dct.settings.server.statepath)
	return 0
end

os.exit(main())
