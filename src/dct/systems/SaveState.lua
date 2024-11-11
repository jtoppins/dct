-- SPDX-License-Identifier: LGPL-3.0

local myos = require("os")
local myio = require("io")
local mylfs = require("lfs")
require("libs")

local class     = libs.classnamed
local Command   = require("dct.libs.Command")
local System    = require("dct.libs.System")
local DCTEvents = require("dct.libs.DCTEvents")

local STATE_VERSION = "1"
local RESETFILE = libs.utils.join_paths(mylfs.writedir(), "reset.txt")

local SaveState = class("SaveState", System, DCTEvents)

SaveState.enabled = true

function SaveState:__init(theater)
	System.__init(self, theater, System.SYSTEMORDER.PERSISTENCE,
		      System.SYSTEMALIAS.PERSISTENCE)
	DCTEvents.__init(self)
	self._savestatefreq = 7 * 60 -- seconds
	self._statepath = libs.utils.join_paths(mylfs.writedir(),
						theater.name..".state")
	self._started = false
	self._loadedState = {}
	self:_overridehandlers({
		[world.event.S_EVENT_MISSION_END] = self.handleMissionEnd,
	})
end

function SaveState:initialize()
	self._tickets = self._theater:getSystem(System.SYSTEMALIAS.TICKETS)
	local statefile, errmsg, errcode = myio.open(self._statepath)

	if statefile == nil then
		self._logger:info("No state found: (%d) %s", errcode, errmsg)
		return
	end

	self._loadedState = libs.json:decode(statefile:read("*all"))
	statefile:close()

	print("loaded state: "..libs.json:encode_pretty(self._loadedState))
	if not self:isValidState() then
		self._loadedState = {}
		return
	end

	-- TODO: need to coordinate with the save function for what the
	-- format looks like
	self._theater:_runsys("unmarshal", self._loadedState)
	self._logger:info("loaded state")
end

function SaveState:start()
	self._theater:addObserver(self.onDCTEvent, self,
				  self.__clsname..".onDCTEvent")
	local cmd = Command(60, self.__clsname..".save", self.save, self)
	cmd:setRequeue(true)
	self._theater:queueCommand(cmd)
	self._started = true
end

function SaveState:hasLoadedState()
	return next(self._loadedState) ~= nil
end

function SaveState:isValidState()
	local sortiename = env.getValueDictByKey(env.mission.sortie)

	if self:hasLoadedState() then
		self._logger:info("state is empty")
		return false
	end

	if myio.open(RESETFILE) ~= nil then
		self._logger:info("state reset requested by file")
		myos.remove(RESETFILE)
		return false
	end

	if self._loadedState.complete == true then
		self._logger:info("theater goals were completed")
		return false
	end

	if self._loadedState.theater ~= env.mission.theatre then
		self._logger:warn("wrong theater; state: '%s'; mission: '%s'",
			self._loadedState.theater, env.mission.theatre)
		return false
	end

	if self._loadedState.sortie ~= sortiename then
		self._logger:warn("wrong sortie; state: '%s'; mission: '%s'",
			self._loadedState.sortie, sortiename)
		return false
	end
	return true
end

-- Only delete the active state if there is an end mission event
-- and tickets are complete, otherwise when a server is shutdown
-- gracefully the state will be deleted.
function SaveState:handleMissionEnd()
	if self._tickets:isComplete() then
		-- Save the now-ended state with a timestamped filename
		self:save(nil, myos.time())
		local ok, err = myos.remove(self._statepath)
		if not ok then
			self._logger:error("unable to remove statefile; %s",
					   err)
		end
	elseif self._started then
		-- Save the state for reloading after a server restart
		self:save()
	end
end

function SaveState:save(_, suffix)
	local path = self._statepath
	local statefile
	local msg

	if suffix ~= nil then
		local noext, ext = string.match(path, "^(.+)(%.[^/\\]+)$")
		path = noext.."_"..tostring(suffix)..ext
	end

	statefile, msg = myio.open(path, "w+")

	if statefile == nil then
		self._logger:error("unable to open '%s'; msg: %s", path,
				   tostring(msg))
		return self._savestatefreq
	end

	local exporttbl = {
		["version"]  = STATE_VERSION,
		--TODO: ["complete"] = self._tickets:isComplete(),
		["date"]     = myos.date("*t",
				dct.libs.utils.zulutime(timer.getAbsTime())),
		["theater"]  = env.mission.theatre,
		["sortie"]   = env.getValueDictByKey(env.mission.sortie),
		["systems"]  = {},
		-- TODO: finalize the save state format.
		--[[
		["startdate"] = self.startdate,
		["namecntr"]  = self.namecntr,
		--]]
	}

	for name, sys in self._theater:iterateSystems() do
		if type(sys.marshal) == "function" then
			exporttbl.systems[name] = sys:marshal()
		end
	end

	statefile:write(libs.json:encode(exporttbl))
	statefile:flush()
	statefile:close()
	return self._savestatefreq
end

return SaveState
