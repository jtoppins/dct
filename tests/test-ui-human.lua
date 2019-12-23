#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local human = require("dct.ui.human")
local enum  = require("dct.enum")

local testairthreat = {
	[1] = {
		["value"] = 0,
		["expected"] = "incapability",
	},
	[2] = {
		["value"] = 20,
		["expected"] = "denial",
	},
	[3] = {
		["value"] = 40,
		["expected"] = "parity",
	},
	[4] = {
		["value"] = 60,
		["expected"] = "superiority",
	},
	[5] = {
		["value"] = 80,
		["expected"] = "supremacy",
	},
}

local testthreat = {
	[1] = {
		["value"] = 0,
		["expected"] = "low",
	},
	[2] = {
		["value"] = 30,
		["expected"] = "medium",
	},
	[3] = {
		["value"] = 70,
		["expected"] = "high",
	},
}

local testlochdr = {
	[1] = {
		["value"] = enum.missionType.STRIKE,
		["expected"] = "Target",
	},
	[2] = {
		["value"] = enum.missionType.CAP,
		["expected"] = "Station",
	},
}

local testgrids = {
	[1] = {
		["value"] = "F-15",
		["expected"] = "",
	},
}

local function main()
	for k, v in ipairs(testairthreat) do
		assert(human.airthreat(v.value) == v.expected,
			"human.airthreat() unexpected value")
	end
	for k, v in ipairs(testthreat) do
		assert(human.threat(v.value) == v.expected,
			"human.threat() unexpected value")
	end
	for k, v in ipairs(testlochdr) do
		assert(human.locationhdr(v.value) == v.expected,
			"human.locationhdr() unexpected value")
	end
	return 0
end

os.exit(main())
