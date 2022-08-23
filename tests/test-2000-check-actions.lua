#!/usr/bin/lua

require("os")
require("lfs")
require("dcttestlibs")
require("dct")
local Agent = require("dct.assets.Agent")

local function check_action(Object, file)
	local agent = Agent()
	assert(Object)
	assert(type(Object.enter) == "function")
	assert(type(Object.isComplete) == "function")
	assert(type(Object.checkProceduralPreconditions) == "function")
	assert(type(Object.complete) ~= "function")

	local obj = Object(agent)
	assert(obj.agent == agent, "problem with: actions/"..file)
end

local function check_sensor(obj)
end

local function check_goal(obj)
end

local basepath = os.getenv("DCT_SRC_ROOT").."/src/dct/assets"
local testcases = {
	{
		system = "actions",
		check = check_action,
	}, {
		system = "sensors",
		check = check_sensor,
	}, {
		system = "goals",
		check = check_goal,
	},
}

local function main()
	for _, tc in ipairs(testcases) do
		for file in lfs.dir(basepath.."/"..tc.system) do
			local st, _, cap1 = string.find(file, "([^.]+)%.lua$")
			if st then
				local Object = require("dct.assets."..
					tc.system.."."..cap1)
				tc.check(Object, cap1)
			end
		end
	end
	return 0
end

os.exit(main())
