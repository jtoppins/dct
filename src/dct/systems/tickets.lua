--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the accounting of a ticket system.
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local Marshallable = require("dct.libs.Marshallable")
local Command  = require("dct.Command")

local function checkvalue(keydata, tbl)
	if tbl[keydata.name] >= 0 then
		return true
	end
	return false
end

local function checkdifficulty(keydata, tbl)
	local val = string.lower(tbl[keydata.name])
	local settings = {
		["easy"] = {
			["player_cost"]     = 1.0,
			["modifier_loss"]   = 0.5,
			["modifier_reward"] = 1.5,
		},
		["normal"] = {
			["player_cost"]     = 1.0,
			["modifier_loss"]   = 1.0,
			["modifier_reward"] = 1.0,
		},
		["hard"] = {
			["player_cost"]     = 1.0,
			["modifier_loss"]   = 1.5,
			["modifier_reward"] = 0.5,
		},
		["realistic"] = {
			["player_cost"]     = 1.0,
			["modifier_loss"]   = 1.0,
			["modifier_reward"] = 0,
		},
		["custom"] = {
		},
	}

	if settings[val] == nil then
		return false
	end
	for k, v in pairs(settings[val]) do
		tbl[k] = v
	end
	return true
end

local function checkside(keydata, tbl)
	local keys = {
		{
			["name"]    = "tickets",
			["type"]    = "number",
			["check"]   = checkvalue,
		}, {
			["name"]    = "player_cost",
			["type"]    = "number",
			["check"]   = checkvalue,
			["default"] = 1,
		}, {
			["name"]    = "modifier_reward",
			["type"]    = "number",
			["check"]   = checkvalue,
			["default"] = 1,
		}, {
			["name"]    = "modifier_loss",
			["type"]    = "number",
			["check"]   = checkvalue,
			["default"] = 1,
		}, {
			["name"]    = "flag",
			["type"]    = "number",
			["check"]   = checkvalue,
		}, {
			["name"]    = "difficulty",
			["type"]    = "string",
			["check"]   = checkdifficulty,
			["default"] = "custom",
		}
	}

	tbl[keydata.name].path = tbl.path
	utils.checkkeys(keys, tbl[keydata.name])
	tbl[keydata.name].path = nil
	tbl[keydata.name].start = tbl[keydata.name].tickets
	return true
end

local Tickets = class(Marshallable)
function Tickets:__init(theater)
	Marshallable.__init(self)
	self.cfgfile = dct.settings.server.theaterpath..utils.sep..
		"theater.goals"
	self.tickets = {}
	self.timeout = {
		["enabled"] = false,
		["ctime"] = timer.getAbsTime(),
		["period"] = 120,
	}
	self.complete = false
	self:readconfig()
	self:_addMarshalNames({
		"tickets",
		"timeout",
		"complete"})
	if self.timeout.enabled then
		theater:queueCommand(self.timeout.period, Command(
			"Tickets.timer", self.timer, self))
	end
end

function Tickets:_unmarshalpost(data)
	for _, tbl in ipairs({"tickets"}) do
		self[tbl] = {}
		for k, v in pairs(data[tbl]) do
			self[tbl][tonumber(k)] = v
		end
	end
end

function Tickets:readconfig()
	local goals = utils.readlua(self.cfgfile)
	local keys = {
		{
			["name"]    = "time",
			["type"]    = "number",
			["check"]   = checkvalue,
			["default"] = -1
		}, {
			["name"]    = "red",
			["type"]    = "table",
			["check"]   = checkside,
		}, {
			["name"]    = "blue",
			["type"]    = "table",
			["check"]   = checkside,
		}, {
			["name"]    = "neutral",
			["type"]    = "table",
			["check"]   = checkside,
		}
	}

	goals.path = self.cfgfile
	utils.checkkeys(keys, goals)
	goals.path = nil

	if goals.time > 0 then
		self.timeout.timeleft = goals.time
		self.timeout.enabled = true
	end
	for _, val in ipairs({"red", "blue", "neutral"}) do
		local s = coalition.side[string.upper(val)]
		self.tickets[s] = goals[val]
	end

	assert(self.tickets[coalition.side.BLUE] ~= nil and
		self.tickets[coalition.side.BLUE].start > 0 and
		self.tickets[coalition.side.RED] ~= nil and
		self.tickets[coalition.side.RED].start > 0,
		string.format("Theater Goals: Red and Blue coalitions must be "..
			"defined and have tickets > 0; %s", self.cfgfile))
end

function Tickets:getConfig(side)
	return self.tickets[side]
end

function Tickets:getPlayerCost(side)
	assert(side == coalition.side.RED or side == coalition.side.BLUE,
		string.format("value error: side(%d) is not red or blue", side))
	return self.tickets[side]["player_cost"]
end

function Tickets:_add(side, cost, mod)
	local t = self.tickets[side]
	assert(t, string.format("value error: side(%d) not valid, resulted in"..
		" nil ticket table", side))
	local v = cost
	if mod ~= nil then
		v = v * t[mod]
	end
	t.tickets = t.tickets + v
end

function Tickets:reward(side, cost, mod)
	local op = nil
	if mod == true then
		op = "modifier_reward"
	end
	self:_add(side, math.abs(cost), op)
end

local winnermap = {
	[coalition.side.RED] = coalition.side.BLUE,
	[coalition.side.BLUE] = coalition.side.RED,
	[coalition.side.NEUTRAL] = coalition.side.NEUTRAL,
}

function Tickets:loss(side, cost, mod)
	local t = self.tickets[side]
	if t.start <= 0 then
		return
	end

	local op = nil
	if mod == true then
		op = "modifier_loss"
	end
	self:_add(side, -math.abs(cost), op)
	if not self:isComplete() and t.tickets < 0 then
		local flag = self.tickets[winnermap[side]].flag
		trigger.action.setUserFlag(flag, true)
		self:setComplete()
	end
end

function Tickets:get(side)
	local t = self.tickets[side]
	if t == nil then
		return nil
	end
	return t.tickets, t.start
end

function Tickets:setComplete()
	self.complete = true
end

function Tickets:isComplete()
	return self.complete
end

function Tickets:timer()
	local ctime = timer.getAbsTime()
	local tdiff = ctime - self.timeout.ctime

	self.timeout.ctime = ctime
	self.timeout.timeleft = self.timeout.timeleft - tdiff
	if self.timeout.timeleft > 0 then
		return self.timeout.period
	end

	-- campaign timeout reached, determine the winner
	local red  = self.tickets[coalition.side.RED]
	local blue = self.tickets[coalition.side.BLUE]
	local civ = self.tickets[coalition.side.NEUTRAL]
	local flag = civ.flag

	if red.tickets < blue.tickets then
		flag = blue.flag
	elseif blue.tickets < red.tickets then
		flag = red.flag
	end
	trigger.action.setUserFlag(flag, true)
	self:setComplete()
	return nil
end

return Tickets
