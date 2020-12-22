#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")
local utils = require("dct.utils")
local json  = require("libs.json")
local aienum  = require("dct.ai.enum")

local deg = '°'
local testll = {
	[1] = {
		["lat"]  = 88.123,
		["long"] = -63.456,
		["precision"] = 0,
		["format"] = utils.posfmt.DD,
		["expected"] = "088"..deg.."N 063"..deg.."W",
	},
	[2] = {
		["lat"]  = 88.123,
		["long"] = -63.456,
		["precision"] = 3,
		["format"] = utils.posfmt.DDM,
		["expected"] = "88"..deg.."07.38'N 063"..deg.."27.36'W",
	},
	[3] = {
		["lat"]  = 88.123,
		["long"] = -63.456,
		["precision"] = 5,
		["format"] = utils.posfmt.DMS,
		["expected"] = "88"..deg.."07'22.800\"N 063"..deg.."27'21.600\"W",
	},
}

local testmgrs = {
	[1] = {
		["mgrs"] = {
			["UTMZone"] = "DD",
			["MGRSDigraph"] = "GJ",
			["Easting"] = 01234,
			["Northing"] = 56789,
		},
		["precision"] = 0,
		["expected"] = "DD GJ",
	},
	[2] = {
		["mgrs"] = {
			["UTMZone"] = "DD",
			["MGRSDigraph"] = "GJ",
			["Easting"] = 01234,
			["Northing"] = 56789,
		},
		["precision"] = 3,
		["expected"] = "DD GJ012567",
	},
}

local testlo = {
	[1] = {
		["position"] = {
			["x"] = 100.2,
			["y"] = 20,
			["z"] = -50.35,
		},
		["precision"] = 3,
		["format"] = utils.posfmt.MGRS,
		["expected"] = "DD GJ012567",
	},
	[2] = {
		["position"] = {
			["x"] = 100.2,
			["y"] = 20,
			["z"] = -50.35,
		},
		["precision"] = 5,
		["format"] = utils.posfmt.DMS,
		["expected"] = "88"..deg.."07'22.800\"N 063"..deg.."27'21.600\"W",
	},
}

local testcentroid = {
	{
		["points"] = {
			[1] = {
				["x"] = 10, ["y"] = -4, ["z"] = 15,
			},
			[2] = {
				["x"] = 5, ["z"] = 2,
			},
			[3] = {
				["y"] = 7, ["z"] = 4,
			},
		},
		["expected"] = {
			["x"] = 5, ["y"] = 7,
		},
	}, {
		["points"] = {
			[1] = {
				["x"] = 10, ["z"] = 15,
			},
			[2] = {
				["x"] = 4, ["z"] = 2,
			},
			[3] = {
				["x"] = 7, ["z"] = 4,
			},
		},
		["expected"] = {
			["x"] = 7, ["y"] = 7,
		},
	}, {
		["points"] = {
			{ ["y"] = -172350.64739488, ["x"] = -26914.832345419, },
			{ ["y"] = -172782.23876319, ["x"] = -26886.142122476, },
			{ ["y"] = -172576.47430698, ["x"] = -27159.936678189, },
		},
		["expected"] = {
			["x"] = -26986.970382028, ["y"] = -172569.786821683,
		},
	}
}

local function main()
	for _, v in ipairs(testll) do
		local str = utils.LLtostring(v.lat, v.long, v.precision, v.format)
		assert(str == v.expected,
			"utils.LLtostring() unexpected value; got: '"..str..
			"'; expected: '"..v.expected.."'")
	end
	for _, v in ipairs(testmgrs) do
		local str = utils.MGRStostring(v.mgrs, v.precision)
		assert(str == v.expected,
			"utils.MGRStostring() unexpected value; got: '"..str..
			"'; expected: '"..v.expected.."'")
	end
	for _, v in ipairs(testlo) do
		local str = utils.fmtposition(v.position, v.precision, v.format)
		assert(str == v.expected,
			"utils.fmtposition unexpected value; got: '"..str..
			"'; expected: '"..v.expected.."'")
	end
	for _, v in ipairs(testcentroid) do
		local centroid, n
		for _, pt in ipairs(v.points) do
			centroid, n = utils.centroid2D(pt, centroid, n)
		end
		assert(math.abs(centroid.x - v.expected.x) < 0.00001 and
			math.abs(centroid.y - v.expected.y) < 0.00001,
			"utils.centroid unexpected value; got: "..
			json:encode_pretty(centroid).."; expected: "..
			json:encode_pretty(v.expected))
	end

	local test_time = 3600*16 -- 16:00 local time
	assert("2016-06-21 16:00l" == os.date("%F %Rl", utils.time(test_time)),
		"failed: "..os.date("%F %Rl", utils.time(test_time)))
	assert("2016-06-21 12:00z" == os.date("%F %Rz", utils.zulutime(test_time)),
		"failed: "..os.date("%F %Rz", utils.zulutime(test_time)))

	assert(utils.calcTACANFreq(74, aienum.BEACON.TACANMODE.X) == 1161000000,
		"TACAN frequency invalid")
	return 0
end

os.exit(main())
