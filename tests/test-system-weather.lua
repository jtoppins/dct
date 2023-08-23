#!/usr/bin/lua

require("dcttestlibs")
require("dct")

local _, grp = dctstubs.createPlayer()

local function main()
	dct.init()
	local theater = dct.Theater.singleton()

	dctstubs.setModelTime(50)
	dctstubs.fastForward(10, 30)

	local weather = theater:getSystem("dct.systems.weather")
	local player = theater:getAssetMgr():getAsset(grp.name)

	assert(weather:metar({x = 1, y = 2, z = 3}, player) ==
		"031BKN 071SCT 68/- 29.92")
	assert(weather:getCeiling() == 3097)
	assert(weather:findVFRAltitude(3000, 2000, 10000) == 2947)
	assert(weather:findVFRAltitude(2500, 2000, 10000) == 2500)
	assert(weather:findVFRAltitude(6000, 2000, 10000) == 6000)
	assert(weather:findVFRAltitude(4000, 2000, 10000) == 2947)
	assert(weather:findVFRAltitude(5000, 4000, 10000) == 5497)
	os.remove(dct.settings.server.statepath)
	return 0
end

os.exit(main())
