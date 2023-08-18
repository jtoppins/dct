#!/usr/bin/lua

require("dcttestlibs")
dofile(os.getenv("DCT_DATA_ROOT").."/../mission/dct-mission-init.lua")
local dctenum = require("dct.enum")
local human = require("dct.ui.human")
local Mission = require("dct.libs.Mission")
local WS = require("dct.assets.worldstate")

local unit1, grp = dctstubs.createPlayer()

local testairthreat = {
	name = "airthreat",
	func = human.airthreat,
	{
		["value"] = 0,
		["expected"] = "incapability",
	}, {
		["value"] = 20,
		["expected"] = "denial",
	}, {
		["value"] = 40,
		["expected"] = "parity",
	}, {
		["value"] = 60,
		["expected"] = "superiority",
	}, {
		["value"] = 80,
		["expected"] = "supremacy",
	},
}

local testthreat = {
	name = "threat",
	func = human.threat,
	{
		["value"] = 0,
		["expected"] = "low",
	}, {
		["value"] = 30,
		["expected"] = "medium",
	}, {
		["value"] = 70,
		["expected"] = "high",
	},
}

local teststr = {
	name = "strength",
	func = human.strength,
	{
		["value"] = nil,
		["expected"] = "Unknown",
	}, {
		["value"] = 22,
		["expected"] = "Critical",
	}, {
		["value"] = 50,
		["expected"] = "Marginal",
	}, {
		["value"] = 100,
		["expected"] = "Nominal",
	}, {
		["value"] = 130,
		["expected"] = "Excellent",
	},
}

local testrel = {
	{
		["v1"] = coalition.side.BLUE,
		["v2"] = coalition.side.BLUE,
		["expected"] = "Friendly",
	}, {
		["v1"] = coalition.side.RED,
		["v2"] = coalition.side.BLUE,
		["expected"] = "Hostile",
	}, {
		["v1"] = coalition.side.RED,
		["v2"] = coalition.side.Neutral,
		["expected"] = "Neutral",
	}, {
		["v1"] = coalition.side.NEUTRAL,
		["v2"] = coalition.side.NEUTRAL,
		["expected"] = "Friendly",
	}
}

local msndesc = {
	description = "Strike mission description",
	location = {1, 2, 5},
	codename = "foo",
}

-- luacheck: max_line_length 500
local msnbrief = "Mission 500 assigned, use F10 menu to see this briefing again.\n\n### Overview\nPackage: #500\nMission: Precision Strike\nAO: 88°07'23\"N 063°27'22\"W (foo)\nProgress: 70% complete\n\n### Description\nStrike mission description\n\n### Comms Plan\nNot Implemented\n\n### Threat Analysis\nNo known threats.\n\n### Package Assets\nP: bobplayer (F/A-18C Hornet)\n\n### Remarks\nNone.\n\n"

local function main()
	for _, tests in pairs({testairthreat, testthreat, teststr}) do
		for _, v in ipairs(tests) do
			assert(tests.func(v.value) == v.expected,
				string.format("human.%s(%s) unexpected value",
				tests.name, tostring(v.value)))
		end
	end
	for _, v in ipairs(testrel) do
		assert(human.relationship(v.v1, v.v2) == v.expected,
			"human.relationship() unexpected value")
	end

	local theater = dct.theater
	dctstubs.setModelTime(50)
	dctstubs.fastForward(10, 30)
	local player = theater:getAssetMgr():getAsset(grp.name)
	dctstubs.runEventHandlers({
		["id"]        = world.event.S_EVENT_BIRTH,
		["initiator"] = unit1,
	})

	dctstubs.fastForward(10, 40)
	local msn = Mission(dctenum.missionType.STRIKE,
		theater:getCommander(player.owner), msndesc)
	msn:setFact(WS.Facts.factKey.HEALTH,
		WS.Facts.Value(WS.Facts.factType.HEALTH,
			.7))
	msn:assign(player)
	trigger.action.setmsgbuffer(msnbrief)
	dctstubs.fastForward(2, 40)
	trigger.action.chkmsgbuffer()
	return 0
end

os.exit(main())
