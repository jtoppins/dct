#!/usr/bin/lua

require("os")
require("dcttestlibs")
require("dct")
local vector = require("dct.libs.vector")
local aienum  = require("dct.ai.enum")
local aitasks = require("dct.ai.tasks")

local function main()
	local task = aitasks.command.createTACAN("TST", 74,
		aienum.BEACON.TACANMODE.X, "test", false, false, true)
	assert(type(task) == "table")

	task = aitasks.option.create(AI.Option.Air.id.REACTION_ON_THREAT,
		AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
	assert(type(task) == "table")

	local mission = aitasks.Mission(true)
	local waypoint = aitasks.Waypoint(AI.Task.WaypointType.TAKEOFF,
		vector.Vector3D.create(5, 10, 2000), 200, "Takeoff")
	waypoint:addTask(
		aitasks.option.create(AI.Option.Air.id.REACTION_ON_THREAT,
			AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE))
	waypoint:addTask(aitasks.command.eplrs(true))
	mission:addWaypoint(waypoint)
	waypoint = aitasks.Waypoint(AI.Task.WaypointType.TURNING_POINT,
		vector.Vector3D.create(100, -430, 1000), 200, "Ingress")
	waypoint:addTask(aitasks.task.orbit(AI.Task.OrbitPattern.RACE_TRACK,
		vector.Vector2D.create(100, -450),
		vector.Vector2D.create(400, -600),
		190, 6500))
	waypoint:addTask(aitasks.task.tanker())
	mission:addWaypoint(waypoint)
	return 0
end

os.exit(main())
