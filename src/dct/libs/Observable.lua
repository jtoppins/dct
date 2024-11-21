-- SPDX-License-Identifier: LGPL-3.0

--- Implements a Observable interface.
-- @classmod dct.libs.Observable

local myos = require("os")
require("libs")

local class = libs.class
local utils = libs.utils

local function notify(self, event)
	self._logger:debug("notify; event.id: %d (%s)",
		event.id, tostring(utils.getkey(world.event, event.id) or
			utils.getkey(dct.event.ID, event.id)))
	for obj, val in pairs(self._observers) do
		self._logger:debug("+ executing handler: %s", val.name)
		val.func(obj, event)
	end
end

local function notifytimed(self, event)
	local tstart = myos.clock()
	notify(self, event)
	self._logger:warn("notify time: %5.2fms", (myos.clock()-tstart)*1000)
end

local Observable = class()

--- Constructor.
-- @param logger reference to dct.libs.Logger instance
function Observable:__init(logger)
	if self._logger == nil then
		self._logger = logger or dct.libs.Logger.getByName("Observable")
	end
	self._observers = {}
	setmetatable(self._observers, { __mode = "k", })

	if dct.settings and dct.settings.server and
	   dct.settings.server.profile then
		self.notify = notifytimed
	end
end

--- Add an Observer to this object.
-- @param func callback to execute when this object needs to notify
--	observers.
-- @param obj the object containing func.
-- @param name a string to identify the observer, used in debug logs.
function Observable:addObserver(func, obj, name)
	assert(type(func) == "function", "func must be a function")
	-- obj must be a table otherwise upon insertion the index which
	-- is obj will cause an access violation.
	assert(type(obj) == "table", "obj must be a table value")
	name = name or "unknown"

	if self._observers[obj] ~= nil then
		return
	end
	self._logger:debug("adding handler(%s)", name)
	self._observers[obj] = { ["func"] = func, ["name"] = name, }
end

--- Remove an observer from monitoring this object.
-- @param obj the observer object to remove.
function Observable:removeObserver(obj)
	assert(type(obj) == "table", "func must be a function")
	self._observers[obj] = nil
end

--- Notify function.
-- If profile is set to true a different notify function will be enabled
-- which tracks how long it takes to notify all observers. This could be
-- beneficial when trying to debug stuttering.
-- @param event the event to notify observers with.
Observable.notify = notify

return Observable
