#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")
local utils = require("dct.utils")
local json  = require("libs.json")

local formats = {
	["DD"] = utils.posfmt.DD,
	["DDM"] = utils.posfmt.DDM,
	["DMS"] = utils.posfmt.DMS,
}

local testll = {
	{
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 0,
		["DD"] = "088°N 063°W",
		["DDM"] = "88°000'N 063°000'W",
		["DMS"] = "88°00'000\"N 063°00'000\"W",
	}, {
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 1,
		["DD"] = "88.1°N 63.5°W",
		["DDM"] = "88°005'N 063°030'W",
		["DMS"] = "88°05'059\"N 063°30'000\"W",
	}, {
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 2,
		["DD"] = "88.12°N 63.46°W",
		["DDM"] = "88°07.2'N 063°27.6'W",
		["DMS"] = "88°07'012\"N 063°27'036\"W",
	}, {
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 3,
		["DD"] = "88.123°N 63.457°W",
		["DDM"] = "88°07.38'N 063°27.42'W",
		["DMS"] = "88°07'22.8\"N 063°27'25.2\"W",
	}, {
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 4,
		["DD"] = "88.1235°N 63.4568°W",
		["DDM"] = "88°07.410'N 063°27.408'W",
		["DMS"] = "88°07'24.60\"N 063°27'24.48\"W",
	}, {
		["lat"]  = 88.12345,
		["long"] = -63.45678,
		["precision"] = 5,
		["DD"] = "88.12345°N 63.45678°W",
		["DDM"] = "88°07.4070'N 063°27.4068'W",
		["DMS"] = "88°07'24.420\"N 063°27'24.408\"W",
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
		["expected"] = "DD GJ 012 567",
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
		["expected"] = "DD GJ 012 567",
	},
	[2] = {
		["position"] = {
			["x"] = 100.2,
			["y"] = 20,
			["z"] = -50.35,
		},
		["precision"] = 5,
		["format"] = utils.posfmt.DMS,
		["expected"] = "88°07'22.800\"N 063°27'21.600\"W",
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
	for _, coord in ipairs(testll) do
		for fmtkey, fmt in pairs(formats) do
			local str = utils.LLtostring(coord.lat, coord.long,
				coord.precision, fmt)
			assert(str == coord[fmtkey], string.format(
				"utils.LLtostring() with %s (precision %d): "..
				"unexpected value; got: '%s'; expected: '%s'",
				fmtkey, coord.precision, str, tostring(coord[fmtkey])))
		end
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
	return 0
end

os.exit(main())
