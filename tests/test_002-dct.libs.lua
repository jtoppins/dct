#!/usr/bin/lua

require 'busted.runner'()
require("libs")
require("testlibs")

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
	},
}

local function sleep(s)
	local n = os.clock() + s
	repeat until os.clock() > n
end

describe("validate dct.libs", function()
	describe("Command", function()
		local function f(a, b, c, time)
			return a + b + c + time
		end

		before_each(function()
			dcttest.setupRuntime()
		end)

		test("delayed execution", function()
			local cmd = dct.libs.Command(5, "test cmd", f, 1, 2, 3)
			local _, r = cmd:execute(500)
			assert.is.equal(r, 506)
		end)
		pending("figure out how to test timedexecute which times how "..
			"long a command takes and logs at debug level.")
	end)

	describe("vector", function()
		local vector
		local a, b, c

		before_each(function()
			dcttest.setupRuntime()
			vector = dct.libs.vector
			a = vector.Vector2D({x=5,y=5})
			b = vector.Vector2D({x=3,y=3})
			c = vector.Vector2D({x=3,y=3})
		end)

		test("magnitude", function()
			assert.is.equal(7071, math.floor(1000 * a:magnitude()))
		end)
		test("inequality", function()
			assert.is_not.equal(a, b)
		end)
		test("equality", function()
			assert.is.equal(c, b)
		end)
		test("vector.unitvec()", function()
			assert.is.equal(1000, math.ceil(vector.unitvec(a):magnitude() * 1000))
		end)
		test("vector subtraction", function()
			assert.is.equal((a - b), vector.Vector2D({x=2,y=2}))
		end)
		test("scalar product", function()
			assert.is.equal((3 * a), vector.Vector2D({x=15,y=15}))
		end)
		test("scalar division", function()
			assert.is.equal((3 * a) / 3, a)
		end)
		test("scalar subtraction", function()
			assert.is.equal((a - 2), vector.Vector2D({x=3,y=3}))
		end)
	end)

	describe("Timer", function()
		local a, b
		before_each(function()
			dcttest.setupRuntime()
		end)

		test("start and update", function()
			a = dct.libs.Timer(15, os.clock)
			b = dct.libs.Timer(2, os.clock)

			a:start()
			b:start()
			sleep(3)
			a:update()
			b:update()
		end)

		test("remain", function()
			assert(a:remain() <= 12)
			assert.is.equal(b:remain(), 0)
		end)

		test("expired", function()
			assert.is_false(a:expired())
			assert.is_true(b:expired())
		end)

		test("reset", function()
			b:reset()
			assert.is.equal(b:remain(), 2)
		end)

		test("extend", function()
			b:extend(2)
			assert.is.equal(b:remain(), 4)
		end)

		pending("test stop method")
	end)

	describe("utils", function()
		test("isenemy", function()
			assert.is_true(dct.libs.utils.isenemy(
				dct.libs.utils.coalition.RED,
				dct.libs.utils.coalition.BLUE))
		end)

		test("foreach_call", function()
			local t = 0
			local tbl = {
				thing1 = {
					sum = function()
						t = t + 1
					end,
				},
				thing2 = {
					sum = function()
						t = t + 1
					end,
				},
			}

			dct.libs.utils.foreach_call(tbl, pairs, "sum")
			assert.is.equal(t, 2)
		end)

		test("interp", function()
			local tbl = {
				["RE1"] = "hello",
				["RE2"] = "joe",
			}

			assert.is.equal(
				dct.libs.utils.interp("%RE1% %RE2%", tbl),
				"hello joe")
		end)

		test("centroid", function()
			for _, v in ipairs(testcentroid) do
				local centroid, n
				for _, pt in ipairs(v.points) do
					centroid, n = dct.libs.utils.centroid2D(pt,
						centroid, n)
				end

				assert(math.abs(centroid.x - v.expected.x) < 0.00001 and
					math.abs(centroid.y - v.expected.y) < 0.00001)
			end
		end)

		test("time", function()
			local test_time = 3600*16 -- 16:00 local time
			assert.is.equal("2016-06-21 16:00l",
				os.date("%F %Rl", dct.libs.utils.time(test_time)))
			assert.is.equal("2016-06-21 12:00z",
				os.date("%F %Rz", dct.libs.utils.zulutime(test_time)))
		end)
	end)
end)
