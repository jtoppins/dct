-- SPDX-License-Identifier: LGPL-3.0

--- Provides a base hooks class which centeralizes common actions.
--- @class DCTHooks

-- luacheck: read_globals log DCS net

local class = require("libs.namedclass")
local settings = require("dct.settings.server")({})


local function try(obj, methodname, ...)
	if obj[methodname] == nil then
		return
	end

	local status, result = pcall(obj[methodname], obj, ...)
	if not status then
		obj:log(log.ERROR, "call to hook(%s) failed; %s\n%s",
			methodname, result, debug.traceback())
		return
	end
	return result
end

local function register_handler(obj)
	local handler = {}
	local methods = {
		["onSimulationStart"]     = true,
		["onSimulationStop"]      = true,
		["onSimulationPause"]     = true,
		["onSimulationResume"]    = true,
		["onSimulationFrame"]     = true,
		["onMissionLoadBegin"]    = true,
		["onMissionLoadProgress"] = true,
		["onMissionLoadEnd"]      = true,
		["onPlayerConnect"]       = true,
		["onPlayerDisconnect"]    = true,
		["onPlayerChangeSlot"]    = true,
		["onPlayerTryChangeSlot"] = true,
		["onPlayerTryConnect"]    = true,
		["onPlayerTrySendChat"]   = true,
		["onPlayerStart"]         = true,
		["onPlayerStop"]          = true,
		["onGameEvent"]           = true,
		["onNetConnect"]          = true,
		["onNetDisconnect"]       = true,
		["onNetMissionChanged"]   = true,
	}

	for methodname, _ in pairs(methods) do
		if type(obj[methodname]) == "function" then
			handler[methodname] = function(...)
				return try(obj, methodname, ...)
			end
		end
	end

	DCS.setUserCallbacks(handler)
	obj:log(log.INFO, "Loaded")
end


local DCTHooks = class("DCTHOOKS")
function DCTHooks:__init()
	self.settings = settings
end

function DCTHooks:log(lvl, fmt, ...)
	log.write(self.__clsname, lvl, string.format(fmt, ...))
end

function DCTHooks:register()
	local loglevel = log.ALERT + log.ERROR + log.WARNING + log.INFO
	if self.settings.server.hookdebug == true then
		loglevel = loglevel + log.DEBUG + log.TRACE
	end

	log.set_output('dct-hooks', self.__clsname, loglevel, log.FULL)

	local status, errmsg = pcall(register_handler, self)
	if not status then
		self:log(log.ERROR, "Load Error: %s", tostring(errmsg))
	end
end

function DCTHooks:getPlayerInfo(id)
	local player = net.get_player_info(id)
	if player and player.slot == '' then
		player.slot = nil
	end
	return player
end

function DCTHooks:isSlotEnabled(slot)
	if slot == nil then
		return false
	end

	local flag = self:rpcSlotEnabled(slot.groupName)
	log.write(self.__clsname, log.DEBUG,
		  string.format("slot(%s) enabled: %s",
				slot.groupName, tostring(flag)))
	if flag == nil then
		flag = true
	end
	return flag
end

function DCTHooks:isMissionEnabled()
	return self:rpcGetFlag("DCTENABLE") >= 1
end

-- Returns: nil on error otherwise data in the requested type
function DCTHooks:doRPC(ctx, cmd, valtype)
	local status, errmsg = net.dostring_in(ctx, string.format("%q", cmd))
	if not status then
		log.write(self.__clsname, log.ERROR,
			  string.format("rpc failed in context(%s): %s",
					ctx, errmsg))
		return
	end

	local val
	if valtype == "number" then
		val = tonumber(status)
	elseif valtype == "boolean" then
		local t = {
			["true"] = true,
			["false"] = false,
		}
		val = t[string.lower(status)]
	elseif valtype == "string" then
		val = status
	elseif valtype == "table" then
		local rc, result = pcall(net.json2lua, status)
		if not rc then
			log.write(self.__clsname, log.ERROR,
				"rpc json decode failed: "..tostring(result))
			log.write(self.__clsname, log.DEBUG,
				"rpc json decode input: "..tostring(status))
			val = nil
		else
			val = result
		end
	else
		log.write(self.__clsname, log.ERROR,
			string.format("rpc unsupported type(%s)", valtype))
		val = nil
	end
	return val
end

function DCTHooks:rpcSendMsgToAll(msg, dtime, clear)
	local cmd = [[
		trigger.action.outText("]]..tostring(msg)..
			[[", ]]..tostring(dtime)..[[, ]]..tostring(clear)..[[);
		return "true"
	]]
	return self:doRPC("server", cmd, "boolean")
end

function DCTHooks:rpcSlotEnabled(grpname)
	local cmd = [[
		local name = "]]..tostring(grpname)..[["
		local en = trigger.misc.getUserFlag(name)
		local kick = trigger.misc.getUserFlag(name.."_kick")
		local result = (en == 1 and kick ~= 1)]]

	if self.settings.server.debug == true then
		cmd = cmd..[[
		env.info(string.format(
			"DCT slot(%s) check - slot: %s; kick: %s; result: %s",
			tostring(name), tostring(en), tostring(kick),
			tostring(result)), false)]]
	end

	cmd = cmd..[[
		return tostring(result)
	]]

	return self:doRPC("server", cmd, "boolean")
end

function DCTHooks:rpcGetFlag(flagname)
	local cmd = [[
		local flag = trigger.misc.getUserFlag("]]..
			tostring(flagname)..[[") or 0
		return tostring(flag)
	]]
	return self:doRPC("server", cmd, "number")
end

function DCTHooks:rpcSetFlag(flagname, value)
	local cmd = [[
		trigger.action.setUserFlag("]]..tostring(flagname)..
			[[",]]..tostring(value)..[[);
		return "true"
	]]
	return self:doRPC("server", cmd, "number")
end

return DCTHooks
