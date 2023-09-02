-- SPDX-License-Identifier: LGPL-3.0

--- Defines the accounting of a ticket system.

require("math")
local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local Timer    = require("dct.libs.Timer")
local Marshallable = require("dct.libs.Marshallable")
local Command  = require("dct.libs.Command")
local Check    = require("dct.templates.checkers.Check")
local UPDATE_TIME = 120

local coa_list = {"red", "blue", "neutral"}

local difficulty = {
	["EASY"] = {
		["player_cost"]     = 1.0,
		["modifier_loss"]   = 0.5,
		["modifier_reward"] = 1.5,
	},
	["NORMAL"] = {
		["player_cost"]     = 1.0,
		["modifier_loss"]   = 1.0,
		["modifier_reward"] = 1.0,
	},
	["HARD"] = {
		["player_cost"]     = 1.0,
		["modifier_loss"]   = 1.5,
		["modifier_reward"] = 0.5,
	},
	["REALISTIC"] = {
		["player_cost"]     = 1.0,
		["modifier_loss"]   = 1.0,
		["modifier_reward"] = 0,
	},
	["CUSTOM"] = {},
}

local CheckSide = class("CheckSide", Check)
function CheckSide:__init()
	Check.__init(self, "Coalition Options", {
		["tickets"] = {
			["type"]    = Check.valuetype.UINT,
			["description"] = [[
Number of tickets the side's ticket pool starts with. The Neutral
faction can start with zero tickets all others must have above zero.]],
		},
		["player_cost"] = {
			["type"]    = Check.valuetype.UINT,
			["default"] = 1,
			["description"] = [[
Defines the cost of each player slot.]],
		},
		["modifier_reward"] = {
			["type"]    = Check.valuetype.UINT,
			["default"] = 1,
			["description"] = [[
Defines the multiplicative modifier that is applied to all rewards the
given faction receives.]],
		},
		["modifier_loss"] = {
			["type"]    = Check.valuetype.UINT,
			["default"] = 1,
			["description"] = [[
Defines the multiplicative modifier that is applied to all losses the
given faction takes.]],
		},
		["difficulty"] = {
			["type"]    = Check.valuetype.TABLEKEYS,
			["values"]  = difficulty,
			["default"] = difficulty.CUSTOM,
			["description"] = [[
Defines some predefined settings for player_cost, modifier_reward, and
modifier_loss. If this is set to anything other than `custom` any
explicitly defined values for player_cost, etc will be overwritten.

%VALUES%]],
		},
		["win_message"] = {
			["type"]    = Check.valuetype.STRING,
			["default"] = "winner",
			["description"] = [[
]],
		},
	}, [[Each coalition definition is required and can have the
following possible options.]])
end

function CheckSide:check(data)
	local ok, key, msg = Check.check(self, data)

	if not ok then
		return false, key, msg
	end

	data.start = data.tickets
	data.win_message = string.gsub(data.win_message, '["]', "\\\"")
	for k, v in pairs(data.difficulty) do
		data[k] = v
	end

	return true
end

local CheckGoals = class("CheckGoals", Check)
function CheckGoals:__init()
	Check.__init(self, "Goals", {
		["time"] = {
			["default"] = -1,
			["type"]    = Check.valuetype.INT,
			["description"] = [[
The total time, in seconds, the campaign will run before a winner is
determined and a new state is generated. Set to zero to disable the
timer.]],
		},
		["red"] = {
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
Table defining the RED coalition's starting tickets, difficulity, and win
message.]],
		},
		["blue"] = {
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
Table defining the BLUE coalition's starting tickets, difficulity, and win
message.]],
		},
		["neutral"] = {
			["type"]    = Check.valuetype.TABLE,
			["description"] = [[
Table defining the NEUTRAL coalition's starting tickets, difficulity, and
win message.]],
		},
	}, [[
Theater goals define the way in which DCT will evaluate the completion
of the campaign. It is a simple ticket system much like what is present
in many AAA FPS titles.

An Example:

**file location:** `<theater-root>/theater.goals`

```lua
time = 43200  -- 12 hours in seconds
blue = {
	tickets         = 100,
	player_cost     = 1,
	modifier_reward = 0.5,
	modifier_loss   = 0.2,
}

neutral = {
	tickets = 0,
}

red = {
	tickets    = 200,
	difficulty = "easy",
}
```]])
end

function CheckGoals:check(data)
	local ok, key, msg = Check.check(self, data)

	if not ok then
		return false, key, msg
	end

	local checkside = CheckSide()

	for _, side in pairs(coa_list) do
		ok, key, msg = checkside:check(data[side])

		if not ok then
			return false, side.."."..key, msg
		end
	end
	return true
end

local Tickets = class("Tickets", Marshallable)
function Tickets:__init(theater)
	Marshallable.__init(self)
	self.cfgfile = dct.settings.server.theaterpath..utils.sep..
		"theater.goals"
	self.tickets = {}
	self.timeout = false
	self.complete = false

	self:readconfig()

	self:_addMarshalNames({
		"tickets",
		"complete"})

	if self.timeout then
		self.timer:start()
		theater:queueCommand(UPDATE_TIME,
			Command("Tickets.update", self.update, self))
	end
end

function Tickets:unmarshal(data)
	self.complete = data.complete
	for k, v in pairs(data.tickets) do
		utils.mergetables(self.tickets[tonumber(k)], v)
	end

	if self.timeout then
		self.timer:reset(data.timeleft)
		self.timer:start()
	end
end

local include_list = {
	["start"]   = true,
	["tickets"] = true,
}

function Tickets:marshal()
	local data = Marshallable.marshal(self, utils.deepcopy)

	for _, coa in pairs(coalition.side) do
		for key, _ in pairs(data.tickets[coa]) do
			if include_list[key] == nil then
				data.tickets[coa][key] = nil
			end
		end
	end

	if self.timeout then
		data.timeleft = self.timer:remain()
	end

	return data
end

function Tickets:readconfig()
	local goals = utils.readlua(self.cfgfile)
	local checker = CheckGoals()
	local ok, key, msg = checker:check(goals)

	if not ok then
		error(string.format("invalid `%s` %s; file: %s",
			tostring(key), tostring(msg), tostring(self.cfgfile)))
	end

	if goals.time > 0 then
		self.timer = Timer(goals.time, timer.getAbsTime)
		self.timeout = true
	end
	for _, val in ipairs(coa_list) do
		local s = coalition.side[string.upper(val)]
		self.tickets[s] = goals[val]
		self.tickets[s].name = val
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
	if not self:isComplete() and t.tickets <= 0 then
		self:setComplete(self.tickets[winnermap[side]])
	end
end

function Tickets:get(side)
	local t = self.tickets[side]
	if t == nil then
		return nil
	end
	return t.tickets, t.start
end

function Tickets:setComplete(winner)
	if self.complete then
		return
	end

	self.complete = true
	local code = string.format([[a_end_mission("%s", "%s", 10)]],
		winner.name, winner.win_message)

	net.dostring_in("mission", string.format("%q", code))
end

function Tickets:isComplete()
	return self.complete
end

function Tickets:update()
	self.timer:update()
	if not self.timer:expired() then
		return UPDATE_TIME
	end

	-- campaign timeout reached, determine the winner
	local red  = self.tickets[coalition.side.RED]
	local blue = self.tickets[coalition.side.BLUE]
	local civ = self.tickets[coalition.side.NEUTRAL]
	local winner = civ

	if red.tickets < blue.tickets then
		winner = blue
	elseif blue.tickets < red.tickets then
		winner = red
	end
	self:setComplete(winner)
	return nil
end

return Tickets
