#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local utils = require("libs.utils")

local sampletpls = {
	[1] = {
		["name"]   = "test-all-types",
		["groups"] = {
			["vehicle"]    = 3,
			["static"]     = 3,
			["helicopter"] = 1,
			["ship"]       = 1,
			["plane"]      = 1,
		},
		["objtype"] = dct.enum.assetType.AMMODUMP,
		["hasDeathGoals"] = false,
	},
	[2] = {
		["name"]   = "test",
		["groups"] = {
			["vehicle"]    = 1,
			["static"]     = 11,
			["helicopter"] = 0,
			["ship"]       = 0,
			["plane"]      = 0,
		},
		["objtype"] = dct.enum.assetType.C2,
		["hasDeathGoals"] = false,
	},
	[3] = {
		["name"]   = "test-death-state",
		["groups"] = {
			["vehicle"]    = 2,
			["static"]     = 1,
			["helicopter"] = 0,
			["ship"]       = 0,
			["plane"]      = 0,
		},
		["objtype"] = dct.enum.assetType.BASEDEFENSE,
		["hasDeathGoals"] = true,
	},
}

--[[
-- test cases:
--  1. test if expected number of groups per group-kind
--       have been read
--  2. verify template type is as expected
--  3. verify death goals
--]]

local function stmexists()
	dct.Template("test",
		lfs.writedir()..utils.sep.."test.stm",
		"dct-does-not-exist")
end

local function dctexists()
	dct.Template("test",
		"stm-does-not-exist",
		lfs.writedir()..utils.sep.."test.dct")
end

local function singleside()
	dct.Template("test",
		lfs.writedir()..utils.sep.."test-both-sides.stm",
		lfs.writedir()..utils.sep.."test.dct")
end

--local json = require("")

local function main()
	local rname = "testregion"

	for _, data in pairs(sampletpls) do
		--print("tplname: "..data.name)
		local t = dct.Template(rname,
			lfs.writedir()..utils.sep..data.name..".stm",
			lfs.writedir()..utils.sep..data.name..".dct")

		-- test: group values read
		for grpname, value in pairs(data.groups) do
			--print("name: "..grpname.." val: "..value)
			local val = 0
			if t.tpldata[grpname] ~= nil then
				val = #t.tpldata[grpname]
			end
			assert(val == value,
				grpname.." expected: "..value.."; got: "..val)
		end

		-- test: template type is as expected
		assert(t.objtype == data.objtype,
			data.name.." unexpected objtype, read: "..t.objtype..
			"; expected: "..data.objtype)

		-- test: death goals
		assert(t.hasDeathGoals == data.hasDeathGoals,
			data.name.." unexpected deathgoal, read: "..
			tostring(t.hasDeathGoals).."; expected: "..
			tostring(data.hasDeathGoals))
	end

	-- test: if a file doesn't exist
	assert(xpcall(stmexists, nil) == false, "dct existance check failed")
	assert(xpcall(dctexists, nil) == false, "stm existance check failed")

	-- test: verify all groups in a template belong to the same side,
	-- as template can only belong to a single side
	assert(xpcall(singleside, nil) == false, "template check containing"..
			"both sides failed")

	return 0
end

os.exit(main())
