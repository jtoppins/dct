#!/usr/bin/lua

require 'busted.runner'()
require("libs")
require("testlibs")

describe("validate dct.ai", function()
	test("Tacan", function()
		dcttest.setupRuntime()
		local Tacan = dct.ai.Tacan
		local tacan

		assert.is.equal(Tacan.getChannelNumber("59X"), 59)
		assert.is.equal(Tacan.getChannelMode("59X"), "X")
		assert.is.equal(Tacan.isValidChannel("126Y"), true)
		assert.is.equal(Tacan.isValidChannel("126Y TKR"), true)
		assert.is.equal(Tacan.isValidChannel("128X"), false)
		assert.is.equal(Tacan.isValidChannel("35A"), false)
		assert.is.equal(Tacan.decodeChannel("35A"), nil)
		assert.is.equal(Tacan.decodeChannel("59X QJ").channel, 59)
		assert.is.equal(Tacan.decodeChannel("59X QJ").mode, "X")

		tacan = Tacan.decodeChannel("59X QJ")
		assert.is.equal(Tacan.getFrequency(tacan.channel,
						   tacan.mode),
				1020000000)
		assert.is.equal(Tacan.decodeChannel("59X QJ").callsign,
				"QJ")

		tacan = Tacan.decodeChannel("73X GW")
		assert.is.equal(Tacan.getFrequency(tacan.channel,
						   tacan.mode),
				1160000000)

		tacan = Tacan.decodeChannel("16Y")
		assert.is.equal(Tacan.getFrequency(tacan.channel,
						   tacan.mode),
				1103000000)
		assert.is.equal(Tacan.decodeChannel("16Y").callsign, nil)
	end)

	test("tasks", function()
		dcttest.setupRuntime()
		local aienum = dct.ai.enum
		local aitasks = dct.ai.tasks
		local vector = dct.libs.vector

		local task = aitasks.command.createTACAN(nil, "TST", 73,
			aienum.BEACON.TACANMODE.X, "test", false,
			false, true)
		assert.are.same(task, {
			["id"] = "ActivateBeacon",
			["params"] = {
				["type"] = aienum.BEACON.TYPE.TACAN,
				["system"] = aienum.BEACON.SYSTEM.TACAN_MOBILE_MODE_X,
				["frequency"] = 1160000000,
				["callsign"] = "TST",
				["name"] = "test",
				["channel"] = 73,
				["modeChannel"] = aienum.BEACON.TACANMODE.X,
			},
		})

		task = aitasks.option.create(AI.Option.Air.id.REACTION_ON_THREAT,
			AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
		assert.are.same(task, {
			["id"] = AI.Option.Air.id.REACTION_ON_THREAT,
			["params"] = AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE,
		})


		local wpt1 = aitasks.Waypoint(vector.Vector3D.create(5, 10, 2000),
			AI.Task.WaypointType.TAKEOFF, nil, 200, "Takeoff")
		wpt1:addTask(
			aitasks.option.create(AI.Option.Air.id.REACTION_ON_THREAT,
				AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE))
		wpt1:addTask(aitasks.command.eplrs(true))

		local wpt2 = aitasks.Waypoint(vector.Vector3D.create(100, -430, 1000),
			AI.Task.WaypointType.TURNING_POINT, nil, 200, "Ingress")
		wpt2:addTask(aitasks.task.orbit(AI.Task.OrbitPattern.RACE_TRACK,
			vector.Vector2D.create(100, -450),
			vector.Vector2D.create(400, -600),
			190, 6500))
		wpt2:addTask(aitasks.task.tanker())
		local route = aitasks.Route(true, {wpt1, wpt2})
		assert.are.same(route:raw(), {
			["id"] = "Mission",
			["params"] = {
				["airborne"] = true,
				["route"] = {
					["points"] = {
						{
							["ETA_locked"] = false,
							["action"] = "From Runway",
							["alt"] = 2000,
							["alt_type"] = "BARO",
							["formation_template"] = "",
							["name"] = "Takeoff",
							["speed"] = 200,
							["speed_locked"] = true,
							["type"] = "TakeOff",
							["x"] = 5,
							["y"] = 10,
							["task"] = {
								["id"] = "ComboTask",
								["params"] = {
									["tasks"] = {
										{
											["id"] = "WrappedAction",
											["params"] = {
												["action"] = {
													["id"] = "Option",
													["params"] = {
														["name"] = AI.Option.Air.id.REACTION_ON_THREAT,
														["value"] = AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE,
													},
												},
											},
										}, {
											["id"] = "EPLRS",
											["params"] = {
												["value"] = true,
											},
										},
									},
								},
							},
						}, {
							["ETA_locked"] = false,
							["action"] = "Turning Point",
							["alt"] = 1000,
							["alt_type"] = "BARO",
							["formation_template"] = "",
							["name"] = "Ingress",
							["speed"] = 200,
							["speed_locked"] = true,
							["type"] = "Turning Point",
							["x"] = 100,
							["y"] = -430,
							["task"] = {
								["id"] = "ComboTask",
								["params"] = {
									["tasks"] = {
										{
											["id"] = "Orbit",
											["params"] = {
												["altitude"] = 6500,
												["pattern"] = "Race-Track",
												["point"] = {
													["x"] = 100,
													["y"] = -450,
												},
												["point2"] = {
													["x"] = 400,
													["y"] = -600,
												},
												["speed"] = 190,
											},
										}, {
											["id"] = "Tanker",
											["params"] = {},
										},
									},
								},
							},
						},
					},
				},
			},
		})
	end)
end)
