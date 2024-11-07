#!/usr/bin/lua

require 'busted.runner'()
require("libs")
require("testlibs")

local function fpEquals(a, b, epsilon)
	local diff = math.abs(a - b)
	return diff <= epsilon
end

describe("validate dct.ui", function()
	describe("draw", function()
		test("objects", function()
			dcttest.setupRuntime()

			local uidraw = dct.ui.draw
			local objs = {
				uidraw.Mark("text to all", {1,1,1}, true),
				uidraw.Mark("text to group", {1,2,3}, false,
					    uidraw.Mark.scopeType.GROUP, 123),
				uidraw.Mark("text to red", {1,2,3}, false,
					    uidraw.Mark.scopeType.COALITION,
					    coalition.side.RED),
				uidraw.Line({{1,1,1}, {2,2,2}}),
				uidraw.PolyLine({{1,1,1},{2,2,2},{3,3,3}}),
				uidraw.Circle({1,1,1}, 10),
				uidraw.Rect({{1,1,1}, {2,2,2}}),
				uidraw.Quad({{1,1,1}, {2,2,2}, {3,3,3},
						{4,4,4}}),
				uidraw.Text({1,1,1}, "text"),
				uidraw.Arrow({{1,1,1}, {2,2,2}}),
			}

			for _, obj in ipairs(objs) do
				obj:draw()
				obj:remove()
			end
		end)
	end)

	describe("human", function()
		test("human.airthreat", function()
			dcttest.setupRuntime()
			local testvec = {
				{
					["value"] = 0,
					["expected"] = "incapability",
				}, {
					["value"] = 20,
					["expected"] = "denial",
				}, {
					["value"] = 40,
					["expected"] = "parity",
				}, {
					["value"] = 60,
					["expected"] = "superiority",
				}, {
					["value"] = 80,
					["expected"] = "supremacy",
				},
			}

			for _, v in ipairs(testvec) do
				assert.is.equal(v.expected,
						dct.ui.human.airthreat(v.value))
			end
		end)

		test("human.threat", function()
			dcttest.setupRuntime()
			local testvec = {
				{
					["value"] = 0,
					["expected"] = "low",
				}, {
					["value"] = 30,
					["expected"] = "medium",
				}, {
					["value"] = 70,
					["expected"] = "high",
				},
			}

			for _, v in ipairs(testvec) do
				assert.is.equal(v.expected,
						dct.ui.human.threat(v.value))
			end
		end)

		test("human.strength", function()
			dcttest.setupRuntime()
			local testvec = {
				{
					["value"] = nil,
					["expected"] = "Unknown",
				}, {
					["value"] = 22,
					["expected"] = "Critical",
				}, {
					["value"] = 50,
					["expected"] = "Marginal",
				}, {
					["value"] = 100,
					["expected"] = "Nominal",
				}, {
					["value"] = 130,
					["expected"] = "Excellent",
				},
			}

			for _, v in ipairs(testvec) do
				assert.is.equal(v.expected,
						dct.ui.human.strength(v.value))
			end
		end)

		test("human.relationship", function()
			dcttest.setupRuntime()
			local testvec = {
				{
					["v1"] = coalition.side.BLUE,
					["v2"] = coalition.side.BLUE,
					["expected"] = "Friendly",
				}, {
					["v1"] = coalition.side.RED,
					["v2"] = coalition.side.BLUE,
					["expected"] = "Hostile",
				}, {
					["v1"] = coalition.side.RED,
					["v2"] = coalition.side.Neutral,
					["expected"] = "Neutral",
				}, {
					["v1"] = coalition.side.NEUTRAL,
					["v2"] = coalition.side.NEUTRAL,
					["expected"] = "Friendly",
				},
			}

			for _, v in ipairs(testvec) do
				assert.is.equal(v.expected,
						dct.ui.human.relationship(v.v1,
									v.v2))
			end
		end)

		test("human.convert", function()
			dcttest.setupRuntime()

			local testvec = {
				{
					name = "knots",
					value = 51.444,
					units = dct.ui.human.units.SPEED,
					fmt = dct.ui.human.speedfmt.KNOTS,
					result = 99.99,
					tolerance = 0.01,
					sym = "kts",
				}, {
					name = "mph",
					value = 51.444,
					units = dct.ui.human.units.SPEED,
					fmt = dct.ui.human.speedfmt.MPH,
					result = 115.07,
					tolerance = 0.01,
					sym = "mph",
				}, {
					name = "kph",
					value = 51.444,
					units = dct.ui.human.units.SPEED,
					fmt = dct.ui.human.speedfmt.KPH,
					result = 185.198,
					tolerance = 0.01,
					sym = "kph",
				}, {
					name = "nautical mile",
					value = 2500,
					units = dct.ui.human.units.DISTANCE,
					fmt = dct.ui.human.distancefmt.NAUTICALMILE,
					result = 1.3498,
					tolerance = 0.01,
					sym = "NM",
				}, {
					name = "statute mile",
					value = 2500,
					units = dct.ui.human.units.DISTANCE,
					fmt = dct.ui.human.distancefmt.STATUTEMILE,
					result = 1.553,
					tolerance = 0.01,
					sym = "sm",
				}, {
					name = "kilometer",
					value = 2500,
					units = dct.ui.human.units.DISTANCE,
					fmt = dct.ui.human.distancefmt.KILOMETER,
					result = 2.5,
					tolerance = 0.01,
					sym = "km",
				}, {
					name = "altitude feed",
					value = 2500,
					units = dct.ui.human.units.ALTITUDE,
					fmt = dct.ui.human.altfmt.FEET,
					result = 8202.1,
					tolerance = 0.01,
					sym = "ft",
				}, {
					name = "altitude meter",
					value = 2500,
					units = dct.ui.human.units.ALTITUDE,
					fmt = dct.ui.human.altfmt.METER,
					result = 2500,
					tolerance = 0.00001,
					sym = "m",
				}, {
					name = "inhg",
					value = 100,
					units = dct.ui.human.units.PRESSURE,
					fmt = dct.ui.human.pressurefmt.INHG,
					result = 0.0295,
					tolerance = 0.001,
					sym = "inHg",
				}, {
					name = "mmhg",
					value = 100,
					units = dct.ui.human.units.PRESSURE,
					fmt = dct.ui.human.pressurefmt.MMHG,
					result = 0.75,
					tolerance = 0.001,
					sym = "mmHg",
				}, {
					name = "hpa",
					value = 100,
					units = dct.ui.human.units.PRESSURE,
					fmt = dct.ui.human.pressurefmt.HPA,
					result = 1,
					tolerance = 0.001,
					sym = "hPa",
				}, {
					name = "mbar",
					value = 100,
					units = dct.ui.human.units.PRESSURE,
					fmt = dct.ui.human.pressurefmt.MBAR,
					result = 10,
					tolerance = 0.001,
					sym = "mbar",
				}, {
					name = "kelvin",
					value = 100,
					units = dct.ui.human.units.TEMP,
					fmt = dct.ui.human.tempfmt.K,
					result = 100,
					tolerance = 0.001,
					sym = "K",
				}, {
					name = "celsius",
					value = 100,
					units = dct.ui.human.units.TEMP,
					fmt = dct.ui.human.tempfmt.C,
					result = -173.15,
					tolerance = 0.001,
					sym = "C",
				}, {
					name = "fahrenheit",
					value = 100,
					units = dct.ui.human.units.TEMP,
					fmt = dct.ui.human.tempfmt.F,
					result = -279.67,
					tolerance = 0.001,
					sym = "F",
				},
			}

			for _, data in ipairs(testvec) do
				local val, sym = dct.ui.human.convert(
							data.value,
							data.units,
							data.fmt)
				assert.is_true(fpEquals(val, data.result,
							data.tolerance),
							data.name)
				assert.is.equal(data.sym, sym, data.name)
			end
		end)

		pending("mission info formatting")
	end)
end)
