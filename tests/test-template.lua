#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local enum = require("dct.enum")
local STM = require("dct.templates.STM")
local Template = require("dct.templates.Template")

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
		["objtype"] = enum.assetType.AMMODUMP,
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
		["objtype"] = enum.assetType.C2,
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
		["objtype"] = enum.assetType.BASEDEFENSE,
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
	Template.fromFile(
		"dct-does-not-exist",
		lfs.writedir().."test.stm")
end

local function dctexists()
	Template.fromFile(
		lfs.writedir().."test.dct",
		"stm-does-not-exist")
end

local function singleside()
	local t = Template.fromFile(
		lfs.writedir().."test.dct",
		lfs.writedir().."test-both-sides.stm")
	assert(t:isValid() == true)
end

local function main()
	for _, data in pairs(sampletpls) do
		--print("tplname: "..data.name)
		local t = Template.fromFile(
			lfs.writedir()..data.name..".dct",
			lfs.writedir()..data.name..".stm")

		assert(t:isValid(), "bad template")

		-- test: group values read
		for grpname, value in pairs(data.groups) do
			--print("name: "..grpname.." val: "..value)
			local cat =
				Unit.Category[STM.categorymap[string.upper(grpname)]]
			local val = 0
			for _, grp in ipairs(t.tpldata) do
				if grp.category == cat then
					val = val + 1
				end
			end
			assert(val == value,
				grpname.." expected: "..value.."; got: "..val)
		end

		-- test: template type is as expected
		assert(t.objtype == data.objtype,
			tostring(data.name).." unexpected objtype, read: "..
			tostring(t.objtype).."; expected: "..
			tostring(data.objtype))

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
	assert(xpcall(singleside, nil) == false, "template check containing "..
			"both sides failed")

	return 0
end

os.exit(main())
