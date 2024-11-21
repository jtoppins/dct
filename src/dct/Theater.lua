-- SPDX-License-Identifier: LGPL-3.0

--- Defines the Theater class.
-- @classmod dct.Theater

-- DCS sanitizes its environment so we have to keep a local reference to
-- the os table.
local myos = require("os")
require("libs")
local class       = libs.classnamed
local containers  = libs.containers
local utils       = libs.utils
local dctutils    = require("dct.libs.utils")
local Observable  = require("dct.libs.Observable")
local Command     = require("dct.libs.Command")
local Timer       = require("dct.libs.Timer")
local settings    = dct.settings.server
local writedir    = lfs.writedir()

--- Component system. Defines a generic way for initializing components
-- of a Theater without directly tying the two systems together.
-- @type ComponentSystem
local ComponentSystem = class("ComponentSystem")

--- Constructor.
function ComponentSystem:__init(logger)
	self._systemscnt = 0
	self._systems  = {}
	self._orderedsystems = {}
	self._aliassystems = {}
	self._initialized = false

	if self._logger == nil then
		self._logger = logger or
				dct.libs.Logger.getByName(self.__clsname)
	end
end

function ComponentSystem:iterateSystems()
	return next, self._systems, nil
end

--- Runs a system method that can optionally be provided by a system.
-- The call is run in a protected context so that one system does not
-- affect the rest of the theater. Any errors will be reported via the
-- logger.
function ComponentSystem:_runsys(methodname, ...)
	dctutils.foreach_protectedcall(self._logger, self._orderedsystems,
				       ipairs, methodname, ...)
end

--- Search for a registered System by name, if it doesn't exist by name
-- search the alias list.
-- @tparam string name of the System registered with the Theater.
-- @treturn[1] System the registered system being sought
-- @treturn[2] nil
function ComponentSystem:getSystem(name)
	local sys = self._systems[name]

	if sys == nil then
		local alias = self._aliassystems[name]
		sys = self._systems[alias]
	end
	return sys
end

--- Register a new System class. It is only valid to register a system
-- before the initialize() method is called. After a call to the initialize()
-- method all attempts to register a new system will be ignored and logged.
-- @tparam System sys the System instance to register.
-- @tparam bool force by default registration does not let you overwrite
--         previously registered Systems. Set to true to force registration
--         and delete any previously registered System with the same alias.
function ComponentSystem:register(sys, force)
	force = force or false

	if sys == nil then
		dctutils.errhandler(
			"value error: sys cannot be nil", self._logger)
		return
	end

	if self._initialized then
		dctutils.errhandler(
			"cannot register a system after Theater:initialize() is called",
			self._logger)
		return
	end

	local alias = self._aliassystems[sys._alias]

	if force and alias ~= nil then
		self._systems[alias] = nil
		self._aliassystems[alias] = nil
		self._logger:info("system override: %s", alias)
	end

	if self._systems[sys.__clsname] ~= nil or
	   self._aliassystems[sys._alias] ~= nil then
		self._logger:error("System '%s' already registered or its alias.",
			sys.__clsname)
		return
	end

	self._systems[sys.__clsname] = sys
	self._aliassystems[sys._alias] = sys.__clsname
	table.insert(self._orderedsystems, sys)
	self._logger:info("registered system: %s", sys.__clsname)
	self._systemscnt = self._systemscnt + 1
end

--- Register built-in enabled systems with the Theater as their default
-- could have been changed. This removes the need for a custom theater
-- to have to register each individual system even if it is built-in.
-- Then sort systems into priority order and run all registered systems'
-- initialize method.
function ComponentSystem:initialize()
	for _, system in dct.systems.iterateEnabled() do
		self:register(system(self))
	end

	self._initialized = true
	table.sort(self._orderedsystems)
	self:_runsys("initialize")
	self._logger:info("systems initialized: %d", self._systemscnt)
end

--- Run all registered systems' start method.
function ComponentSystem:start()
	self:_runsys("start")
end

--- Base class that reads in all region and template information
-- and provides a base interface for manipulating data at a theater
-- level.
-- @type Theater
local Theater = class("Theater", Observable, ComponentSystem)

--- Create a Theater class. Implements a singleton pattern so only one Theater
-- class can ever exist in a given mission instance.
-- @treturn Theater
function Theater.singleton()
	if dct.theater ~= nil then
		return dct.theater
	end

	dct.theater = Theater()
	return dct.theater
end

--- Constructor. Creates instances of all objects the Theater may
-- need including systems.
function Theater:__init()
	self._logger = dct.libs.Logger.getByName("Theater")
	Observable.__init(self)
	ComponentSystem.__init(self)
	self._running = false
	self.name = string.lower(env.mission.theatre).."_"..
		string.lower(env.getValueDictByKey(env.mission.sortie))
	self.map = env.mission.theatre
	self._path = utils.join_paths(writedir, "DCT", "theaters", self.name)
	self.cmdmindelay   = 2
	self:setTimings(settings.schedfreq, settings.tgtfps,
		settings.percentTimeAllowed)
	self.qtimer    = Timer(self.quanta, myos.clock)
	self.cmdq      = containers.PriorityQueue()
	self.namecntr  = 1000

	trigger.action.setUserFlag("DCTENABLE_SLOTS", settings.enableslots)
	self.singleton = nil
end

--- Set delay timings in the clamped command processing loop.
-- These values will be used in calculating the overall quanta
-- DCT is allowed to use before yielding to DCS.
-- @param cmdfreq float @the frequency at which a new command in processed
-- @param tgtfps number @the FPS target DCT is targeting
-- @param percent float @percentage of time DCT is allowed to utilize
function Theater:setTimings(cmdfreq, tgtfps, percent)
	self._cmdqfreq    = cmdfreq
	self._targetfps   = tgtfps
	self._tallowed    = percent
	self.cmdqdelay    = 1/self._cmdqfreq
	self.quanta       = self._tallowed * ((1 / self._targetfps) *
		self.cmdqdelay)
end

--- Initialize the theater, reading saved state or creating a new theater.
-- Run all component initialize() methods.
function Theater:initialize()
	ComponentSystem.initialize(self)
	self:queueCommand(Command(5, self.__clsname..".start",
		self.start, self))
end

--- Start the theater, run all system start methods, and emit DCT
-- started event.
function Theater:start()
	ComponentSystem.start(self)
	world.onEvent(dct.event.build.initcomplete(self))
end

--- Run the theater. Registers `Theater.exec` and `Theater.onEvent` with the
-- DCS mission scripting engine API so DCT can periodically execute code
-- and receive events from DCS. These two theater functions are the only
-- functions registered with DCS.
function Theater:run()
	if self._running == true then
		return
	end

	self._running = true
	self:queueCommand(Command(5, self.__clsname..".initialize",
		self.initialize, self))
	world.addEventHandler(self)
	timer.scheduleFunction(self.exec, self, timer.getTime() + 20)
end

--- Accessor to get the path where the theater definition is stored.
function Theater:getPath()
	return self._path
end

local airbase_cats = {
	[Airbase.Category.HELIPAD] = true,
	[Airbase.Category.SHIP]    = true,
}

local function handlefarps(airbase, event)
	if event.place ~= nil or
	   airbase:getCategory() ~= Object.Category.BASE or
	   airbase_cats[airbase:getDesc().category] == nil then
		return
	end
	event.place = airbase
end

local airbase_events = {
	[world.event.S_EVENT_TAKEOFF] = true,
	[world.event.S_EVENT_LAND]    = true,
}

-- some airbases (invisible FARPs seems to be the only one currently)
-- do not trigger takeoff and land events, this function figures out
-- if there is a FARP near the event and if so uses that FARP as the
-- place for the event.
local function fixup_airbase(event)
	if airbase_events[event.id] == nil or event.place ~= nil then
		return
	end
	local vol = {
		id = world.VolumeType.SPHERE,
		params = {
			point  = event.initiator:getPoint(),
			radius = 700, -- meters
		},
	}
	world.searchObjects(Object.Category.BASE, vol, handlefarps, event)
end

-- ignore unnecessary events from DCS
local irrelevants = {
	[world.event.S_EVENT_BASE_CAPTURED]                = true,
	[world.event.S_EVENT_TOOK_CONTROL]                 = true,
	[world.event.S_EVENT_HUMAN_FAILURE]                = true,
	[world.event.S_EVENT_DETAILED_FAILURE]             = true,
	[world.event.S_EVENT_PLAYER_ENTER_UNIT]            = true,
	[world.event.S_EVENT_PLAYER_LEAVE_UNIT]            = true,
	[world.event.S_EVENT_PLAYER_COMMENT]               = true,
	[world.event.S_EVENT_SCORE]                        = true,
	[world.event.S_EVENT_DISCARD_CHAIR_AFTER_EJECTION] = true,
	[world.event.S_EVENT_WEAPON_ADD]                   = true,
	[world.event.S_EVENT_TRIGGER_ZONE]                 = true,
	[world.event.S_EVENT_LANDING_QUALITY_MARK]         = true,
	[world.event.S_EVENT_BDA]                          = true,
}

--- Actual event handler so that the event handlers can be executed under
-- a protected context.
-- @tparam DCSEvent event event table received from DCS.
function Theater:_onEvent(event)
	if irrelevants[event.id] ~= nil then
		return
	end
	fixup_airbase(event)
	self:notify(event)
end

--- DCS looks for this function in any table we register with the world
-- event handler.
-- @tparam DCSEvent event event table received from DCS.
function Theater:onEvent(event)
	local ok, err = pcall(self._onEvent, self, event)

	if not ok then
		dctutils.errhandler(err, self._logger)
	end
end

--- Monotonically increasing counter.
function Theater:getcntr()
	self.namecntr = self.namecntr + 1
	return self.namecntr
end

--- Queue a command that needs to be executed later.
-- @tparam Command cmd the Command to execute later.
function Theater:queueCommand(cmd)
	if cmd.delay < self.cmdmindelay then
		self._logger:warn("queueCommand(); delay(%2.2f) less than "..
			    "scheduler minimum(%2.2f), setting to scheduler "..
			    "minimum", cmd.delay, self.cmdmindelay)
		cmd.delay = self.cmdmindelay
	end
	self.cmdq:push(timer.getTime() + cmd.delay, cmd)
	self._logger:debug("queueCommand(); cmd(%s), delay: %d, cmdq size: %d",
		cmd.name, cmd.delay, self.cmdq:size())
end

--- execute queued commands
function Theater:exec(time)
	local cmdctr = 0

	self.qtimer:reset()
	while not self.cmdq:empty() do
		local _, prio = self.cmdq:peek()
		if time < prio then
			break
		end

		local cmd = self.cmdq:pop()
		local ok, requeue = cmd:execute(time)

		if not ok then
			dctutils.errhandler(requeue, self._logger, 2)

			if cmd.requeueOnError == true then
				self:queueCommand(cmd)
			end
		elseif ok and type(requeue) == "number" then
			cmd.delay = requeue
			self:queueCommand(cmd)
		end

		cmdctr = cmdctr + 1
		self.qtimer:update()
		if self.qtimer:expired() then
			self._logger:debug("exec(); quanta reached, quanta: %5.2fms",
				     self.quanta * 1000)
			break
		end
	end
	self.qtimer:update()
	if settings.profile then
		self._logger:debug("exec(); time taken: %4.2fms; cmds executed: %d",
			     self.qtimer.timeout * 1000, cmdctr)
	end
	return time + self.cmdqdelay
end

return Theater
