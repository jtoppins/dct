#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local Agent = require("dct.assets.Agent")
local Sensor = require("dct.assets.sensors.PlayerSensor")

local function main()
	local agent = Agent()
	local sensor = Sensor(agent, 5)

	assert(sensor:isa(Sensor))
	return 0
end

os.exit(main())
