--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Library of functions to generate task tables.
--]]

local class = require("libs.class")
local utils = require("libs.utils")
local check = require("libs.check")
local vector = require("dct.libs.vector")
local aienum = require("dct.ai.enum")

local function create_task_tbl(id, params)
	local task = {}
	task.id     = id
	task.params = params or {}
	return task
end

local tasks = {}

-- Generic helper functions

function tasks.wraptask(task, tasktype)
	return {
		["type"] = tasktype,
		["data"] = task,
	}
end

-- Execute Task List

local function doCommand(controller, task)
	controller:setCommand(task)
end

local function doOption(controller, task)
	controller:setOption(task.id, task.param)
end

function tasks.setTask(controller, task)
	controller:setTask(task)
end

function tasks.pushTask(controller, task)
	controller:pushTask(task)
end

--[[
--  {
--    type = cmd|option|task,
--    data = {
--      id = <task/cmd/option id>,
--      param = <value>,
--    },
--  }
--]]
function tasks.execute(controller, tasklist, taskfunc)
	assert(controller,
		"value error: controller need to be a DCS controller instance.")
	assert(type(tasklist) == "table",
		"value error: the task list must be a table.")
	assert(type(taskfunc) == "function" or taskfunc == nil,
		"value error: [optional] taskfnc must be a function if provided.")
	taskfunc = taskfunc or tasks.pushTask
	local switch = {
		[aienum.TASKTYPE.COMMAND] = doCommand,
		[aienum.TASKTYPE.OPTION]  = doOption,
		[aienum.TASKTYPE.TASK]    = taskfunc,
	}
	for _, task in ipairs(tasklist) do
		local handler = switch[task.type]
		if handler ~= nil then
			handler(controller, task.data)
		else
			dct.Logger.getByName("AI"):error(
				"no handler found for task type: "..tostring(task.type))
		end
	end
end

-- Options

tasks.option = {}
function tasks.option.create(optid, value)
	return create_task_tbl(optid, value), aienum.TASKTYPE.OPTION
end

function tasks.option.createAirFormation(ftype, dist, side)
	local base = 65536
	local formation = check.tblkey(ftype, aienum.FORMATION.TYPE,
		"enum.FORMATION.TYPE")
	side = side or 0

	if dist ~= nil then
		formation = (ftype * base) + dist + side
	end
	return tasks.option.create(AI.Option.Air.id.FORMATION, formation)
end

-- Commands

tasks.command = {}
function tasks.command.activateBeacon(freq, bcntype, system, callsign,
								 name, extratbl)
	assert(type(extratbl) == "table" or extratbl == nil,
		"value error: extratbl must be a table or nil.")
	extratbl = extratbl or {}
	local params = {
		["type"] = check.tblkey(bcntype, aienum.BEACON.TYPE,
			"enum.BEACON.TYPE"),
		["system"] = check.tblkey(system, aienum.BEACON.SYSTEM,
			"enum.BEACON.SYSTEM"),
		["callsign"] = check.string(callsign),
		["frequency"] = check.number(freq),
	}

	if name then
		params.name = check.string(name)
	end
	params = utils.mergetables(params, extratbl)
	return create_task_tbl('ActivateBeacon', params),
		aienum.TASKTYPE.COMMAND
end

function tasks.command.createTACAN(callsign, channel, mode,
							  name, aa, bearing, mobile)
	local bcntype = aienum.BEACON.TYPE.TACAN
	local system = aienum.BEACON.SYSTEM.TACAN
	local freq = require("dct.utils").calcTACANFreq(channel, mode)
	local extra = {}

	extra.channel = channel
	extra.modeChannel = mode
	if aa then
		extra.AA = true
	end
	if bearing then
		extra.bearing = true
	end

	if aa and bearing then
		system = aienum.BEACON.SYSTEM.TACAN_TANKER_MODE_X
		if mode == aienum.BEACON.TACANMODE.Y then
			system = aienum.BEACON.SYSTEM.TACAN_TANKER_MODE_Y
		end
	elseif aa then
		system = aienum.BEACON.SYSTEM.TACAN_AA_MODE_X
		if mode == aienum.BEACON.TACANMODE.Y then
			system = aienum.BEACON.SYSTEM.TACAN_AA_MODE_Y
		end
	elseif mobile then
		system = aienum.BEACON.SYSTEM.TACAN_MOBILE_MODE_X
		if mode == aienum.BEACON.TACANMODE.Y then
			system = aienum.BEACON.SYSTEM.TACAN_MOBILE_MODE_Y
		end
	end

	return tasks.command.activateBeacon(freq, bcntype, system, callsign,
		name, extra)
end

function tasks.command.deactivateBeacon()
	return create_task_tbl('DeactivateBeacon'), aienum.TASKTYPE.COMMAND
end

function tasks.command.eplrs(enable)
	local task = create_task_tbl('EPLRS')
	task.params.value = check.bool(enable)
	return task, aienum.TASKTYPE.COMMAND
end

function tasks.command.script(scriptstring)
	assert(loadstring(scriptstring))
	local task = create_task_tbl('Script')
	task.params.command = scriptstring
	return task, aienum.TASKTYPE.COMMAND
end

function tasks.command.setCallsign(callname, num)
	local params = {
		["callname"] = check.range(callname, 1, 18),
		["number"]   = check.range(num, 1, 9),
	}
	return create_task_tbl('SetCallsign', params),
		aienum.TASKTYPE.COMMAND
end

function tasks.command.setFrequency(freq, mod)
	local params = {
		frequency  = check.number(freq),
		modulation = check.tblkey(mod, radio.modulation,
			"radio.modulation"),
	}
	return create_task_tbl('SetFrequency', params),
		aienum.TASKTYPE.COMMAND
end

function tasks.command.setImmortal(enable)
	local task = create_task_tbl('SetImmortal')
	task.params.value = check.bool(enable)
	return task, aienum.TASKTYPE.COMMAND
end

function tasks.command.setInvisible(enable)
	local task = create_task_tbl('SetInvisible')
	task.params.value = check.bool(enable)
	return task, aienum.TASKTYPE.COMMAND
end

function tasks.command.start()
	return create_task_tbl('Start'), aienum.TASKTYPE.COMMAND
end

function tasks.command.stopRoute(enable)
	local task = create_task_tbl('StopRoute')
	task.params.value = check.bool(enable)
	return task, aienum.TASKTYPE.COMMAND
end

function tasks.command.stopTransmission()
	return create_task_tbl('StopTransmission'), aienum.TASKTYPE.COMMAND
end

function tasks.command.startTransmission(file, duration, loop, subtitle)
	assert(type(file) == "string", "value error: file must be a string.")
	assert(type(duration) == "number" or duration == nil,
		"value error: [optional] duration must be a number.")
	assert(type(loop) == "boolean" or loop == nil,
		"value error: [optional] loop must be a boolean.")
	assert(type(subtitle) == "string" or subtitle == nil,
		"value error: [optional] subtitle must be a string.")
	loop = loop or false
	local params = {
		["duration"] = duration,
		["subtitle"] = subtitle,
		["loop"]     = loop,
		["file"]     = file,
	}
	return create_task_tbl('TransmitMessage', params),
		aienum.TASKTYPE.COMMAND
end

-- Tasks

tasks.task = {}
function tasks.task.awacs()
	return create_task_tbl('AWACS'), aienum.TASKTYPE.TASK
end

function tasks.task.ewr()
	return create_task_tbl('EWR'), aienum.TASKTYPE.TASK
end

function tasks.task.hold()
	return create_task_tbl('Hold'), aienum.TASKTYPE.TASK
end

function tasks.task.refueling()
	return create_task_tbl('Refueling'), aienum.TASKTYPE.TASK
end

function tasks.task.tanker()
	return create_task_tbl('Tanker'), aienum.TASKTYPE.TASK
end

function tasks.task.orbit(pat, pt1, pt2, speed, alt)
	local params = {
		["pattern"]  = check.tblkey(pat, AI.Task.OrbitPattern,
			"AI.Task.OrbitPattern")
	}
	if pt1 then
		params.point = vector.Vector2D(pt1):raw()
	end

	if pt2 then
		params.point2 = vector.Vector2D(pt2):raw()
	end

	if speed then
		params.speed = check.number(speed)
	end

	if alt then
		params.altitude = check.number(alt)
	end
	return create_task_tbl('Orbit', params), aienum.TASKTYPE.TASK
end

function tasks.task.follow(gid, pos, wptidx)
	local params = {
		["groupId"] = check.number(gid),
		["pos"]     = vector.Vector3D(pos):raw(),
	}

	if wptidx then
		params.lastWptIndexFlag = true
		params.listWptIndex     = check.number(wptidx)
	end
	return create_task_tbl('Follow', params), aienum.TASKTYPE.TASK
end

function tasks.task.followBig(gid, pos, wptidx)
	local task, tasktype = tasks.task.follow(gid, pos, wptidx)
	task.id = 'FollowBigFormation'
	return task, tasktype
end

function tasks.task.escort(gid, pos, engagedist, tgtlist, wptidx)
	local task, tasktype = tasks.task.follow(gid, pos, wptidx)

	task.id                       = 'Escort'
	task.params.engagementDistMax = check.number(engagedist)
	task.params.targetTypes       = check.table(tgtlist)
	return task, tasktype
end

function tasks.task.fireAtPoint(pt, rad, expend, wpntype)
	local params = {
		point      = vector.Vector2D(pt):raw(),
	}

	if rad then
		params.radius = check.number(rad)
	end

	if wpntype then
		params.weaponType = check.number(wpntype)
	end

	if expend then
		params.expendQtyEnabled = true
		params.expendQty        = check.number(expend)
	end
	return create_task_tbl('FireAtPoint', params), aienum.TASKTYPE.TASK
end

local function check_optional_params(params, wpntype, wpnexpend, attackqty,
	dir, grpatk, prio)
	if wpntype then
		params.weaponType = check.number(wpntype)
	end

	if wpnexpend then
		params.expend = check.tblkey(wpnexpend, AI.Task.WeaponExpend,
			"AI.Task.WeaponExpend")
	end

	if dir then
		params.direction = check.range(dir, 0, 359)
	end

	if grpatk then
		params.groupAttack = check.bool(grpatk)
	end

	if attackqty then
		params.attackQtyLimit = true
		params.attackQty      = check.number(attackqty)
	end

	if prio then
		params.priority = check.number(prio)
	end
	return params
end

function tasks.task.attackMapObject(pt, wpntype, wpnexpend, attackqty,
									dir, grpatk)
	local params = {}
	params.point = vector.Vector2D(pt):raw()
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, grpatk)
	return create_task_tbl('AttackMapObject', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.attackUnit(id, wpntype, wpnexpend, attackqty,
							   dir, grpatk)
	local params = {}
	params.unitId = check.number(id)
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, grpatk)
	return create_task_tbl('AttackUnit', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.carpetBombing(pt, len, alt, wpntype, wpnexpend,
								  attackqty, grpatk)
	local params = {
		attackType   = 'Carpet',
		point        = vector.Vector2D(pt):raw(),
		carpetLength = check.number(len),
	}

	if alt then
		params.altitudeEnabled = true
		params.altitude        = alt
	end
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		nil, grpatk)
	return create_task_tbl('CarpetBombing', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.bombing(pt, alt, wpntype, wpnexpend,
							attackqty, dir, grpatk)
	local params = {}
	params.point = vector.Vector2D(pt):raw()

	if alt then
		params.altitudeEnabled = true
		params.altitude        = alt
	end
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, grpatk)
	return create_task_tbl('Bombing', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.bombingRunway(id, wpntype, wpnexpend,
								  attackqty, dir, grpatk)
	local params = {}
	params.runwayId = id
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, grpatk)
	return create_task_tbl('BombingRunway', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.engageGroup(id, wpntype, wpnexpend,
								attackqty, dir, prio)
	local params = {}
	params.groupId = check.number(id)
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, nil, prio)
	return create_task_tbl('EngageGroup', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.engageUnit(id, wpntype, wpnexpend,
							   attackqty, dir, grpatk, prio)
	local params = {}
	params.unitId = check.number(id)
	params = check_optional_params(params, wpntype, wpnexpend, attackqty,
		dir, grpatk, prio)
	return create_task_tbl('EngageUnit', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.engageTargets(tgtlist, dist, prio)
	local params = {
		targetTypes = check.table(tgtlist),
		maxDist     = check.number(dist),
		priority    = check.number(prio),
	}

	return create_task_tbl('EngageTargets', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.engageTargetsInZone(tgtlist, pt, radius, prio)
	local params = {
		targetTypes = check.table(tgtlist),
		point       = vector.Vector2D(pt):raw(),
		zoneRadius  = check.number(radius),
		priority    = check.number(prio),
	}

	return create_task_tbl('EngageTargetsInZone', params),
		aienum.TASKTYPE.TASK
end

function tasks.task.fac(freq, mod, callid, callnum, prio)
	local params = {
		frequency  = check.number(freq),
		modulation = check.tblkey(mod, radio.modulation,
			"radio.modulation"),
		callname = check.range(callid, 1, 18),
		number   = check.range(callnum, 1, 9),
		priority    = check.number(prio),
	}
	return create_task_tbl('FAC', params), aienum.TASKTYPE.TASK
end

function tasks.task.wrappedaction(optiontbl)
	local params = {}
	params.action = {
		["id"] = "Option",
		["params"] = {
			["value"] = optiontbl.params,
			["name"]  = optiontbl.id,
		},
	}
	return create_task_tbl('WrappedAction', params), aienum.TASKTYPE.TASK
end

tasks.Waypoint = class()
function tasks.Waypoint:__init(wtype, vec3, speed, name)
	self.name  = name
	self.tasks = {}
	self:setPoint(vec3, wtype, AI.Task.TurnMethod.TURNING_POINT)
	self:setAlt(vec3.y, AI.Task.AltitudeType.BARO)
	self:setSpeed(speed)
end

function tasks.Waypoint:setPoint(vec2, wptype, method)
	self.point = vector.Vector2D(vec2)

	if wptype ~= nil then
		self.type = check.tblkey(wptype, AI.Task.WaypointType,
			"AI.Task.WaypointType")
	end

	if method ~= nil then
		self.action = check.tblkey(method, AI.Task.TurnMethod,
			"AI.Task.TurnMethod")
	end
end

function tasks.Waypoint:setAlt(alt, alttype)
	self.alt      = check.number(alt)
	self.alt_type = check.tblkey(alttype, AI.Task.AltitudeType,
		"AI.Task.AltitudeType")
end

function tasks.Waypoint:setSpeed(spd)
	self.speed        = check.number(spd)
	self.speed_locked = true
	self.ETA_locked   = false
end

function tasks.Waypoint:setETA(time)
	self.ETA          = timer.getAbsTime() + check.number(time)
	self.ETA_locked   = true
	self.speed_locked = false
end

function tasks.Waypoint:addTask(task, tasktype)
	table.insert(self.tasks, tasks.wraptask(task, tasktype))
end

function tasks.Waypoint:removeTask(idx)
	return table.remove(self.tasks, idx)
end

function tasks.Waypoint:raw()
	local attrs = {
		"name", "type", "action", "alt", "alt_type",
		"speed", "speed_locked", "ETA", "ETA_locked",
	}
	local tbl = {}
	for _, attr in pairs(attrs) do
		tbl[attr] = self[attr]
	end
	tbl = utils.mergetables(tbl, self.point:raw())
	if next(self.tasks) then
		tbl.task = {
			["id"] = "ComboTask",
			["params"] = {
				["tasks"] = {},
			},
		}

		for _, task in ipairs(self.tasks) do
			local data = task.data
			if task.type == aienum.TASKTYPE.OPTION then
				data = tasks.task.wrappedaction(task.data)
			end
			table.insert(tbl.task.params.tasks, data)
		end
	end
	return tbl
end

tasks.Mission = class()
function tasks.Mission:__init(airborne)
	self.airborne = airborne
	self.waypoints = {}
end

function tasks.Mission:addWaypoint(wpt)
	table.insert(self.waypoints, wpt)
end

function tasks.Mission:raw()
	local params = {}
	params.airborne = self.airborne
	params.route = {}
	params.route.points = {}
	for _, wypt in ipairs(self.waypoints) do
		table.insert(params.route.points, wypt:raw())
	end
	return create_task_tbl('Mission', params), aienum.TASKTYPE.TASK
end

return tasks
