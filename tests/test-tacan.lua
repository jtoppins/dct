#!/usr/bin/lua

require("os")
local Tacan = require("dct.ai.tacan")

local function assert_equal(a, b)
	assert(a == b, string.format(
		"assertion failed! values not equal:\na: %s\nb: %s",
		tostring(a), tostring(b)))
end

local function main()
	local tacan

	assert_equal(Tacan.getChannelNumber("59X"), 59)
	assert_equal(Tacan.getChannelMode("59X"), "X")
	assert_equal(Tacan.isValidChannel("126Y"), true)
	assert_equal(Tacan.isValidChannel("126Y TKR"), true)
	assert_equal(Tacan.isValidChannel("128X"), false)
	assert_equal(Tacan.isValidChannel("35A"), false)
	assert_equal(Tacan.decodeChannel("35A"), nil)
	assert_equal(Tacan.decodeChannel("59X QJ").channel, 59)
	assert_equal(Tacan.decodeChannel("59X QJ").mode, "X")
	tacan = Tacan.decodeChannel("59X QJ")
	assert_equal(Tacan.getFrequency(tacan.channel, tacan.mode), 1020000000)
	assert_equal(Tacan.decodeChannel("59X QJ").callsign, "QJ")
	tacan = Tacan.decodeChannel("73X GW")
	assert_equal(Tacan.getFrequency(tacan.channel, tacan.mode), 1160000000)
	tacan = Tacan.decodeChannel("16Y")
	assert_equal(Tacan.getFrequency(tacan.channel, tacan.mode), 1103000000)
	assert_equal(Tacan.decodeChannel("16Y").callsign, nil)
	return 0
end

os.exit(main())
