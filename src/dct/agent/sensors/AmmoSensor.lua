-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local dctenum     = require("dct.enum")
local Timer       = require("dct.libs.Timer")
local DCTEvents   = require("dct.libs.DCTEvents")
local AmmoCount   = require("dct.libs.AmmoCount")
local WS          = require("dct.agent.worldstate")
local UPDATE_TIME = 180


local function get_totals(agent)
	local ammo = {}

	for _, v in pairs(dctenum.weaponCategory) do
		ammo[v] = 0
	end

	for _, unit in agent:iterateUnits() do
		local U = Unit.getByName(unit.name)

		if U then
			local totals = loadout.total(U, {}, nil, 1)

			for cat, tot in pairs(totals) do
				ammo[cat] = ammo[cat] + tot.current
			end
		end
	end

	return ammo
end

local function factkey(name)
	return WS.Facts.factKey[string.upper("AMMO"..name)]
end

local function set_has_ammo(maxammo, agent)
	if maxammo > 0 then
		agent:WS():get(WS.ID.HASAMMO).value = true
	else
		agent:WS():get(WS.ID.HASAMMO).value = false
	end
end


--- @classmod AmmoSensor
-- Tracks how much ammo is remaining. The sensor will set ammo state
-- of the agent.
local AmmoSensor = class("AmmoSensor",
	WS.Sensor, DCTEvents)
function AmmoSensor:__init(agent)
	WS.Sensor.__init(self, agent, 40)
	DCTEvents.__init(self)
	self.timer = Timer(UPDATE_TIME)
	self.fired = false

	self:_overridehandlers({
		[world.event.S_EVENT_SHOT] = self.handleShot,
		[world.event.S_EVENT_SHOOTING_END] = self.handleShot,
	})
end

function AmmoSensor:handleShot(--[[event]])
	self.fired = true
end

function AmmoSensor:spawnPost()
	self.initialammo = get_totals(self.agent)
	self.timer:reset()
	self.timer:start()

	local maxammo = 0

	for name, cat in pairs(dctenum.weaponCategory) do
		local key = factkey(name)
		local fact = WS.Facts.Value(WS.Facts.factType.AMMO, 1)

		if self.initialammo[cat] == 0 then
			fact.value.value = 0
		end

		self.agent:setFact(key, fact)
		maxammo = math.max(maxammo, fact.value.value)
	end

	set_has_ammo(maxammo, self.agent)
end

function AmmoSensor:despawnPost()
	self.timer:stop()
end

function AmmoSensor:update()
	self.timer:update()
	if not self.timer:expired() or not self.fired then
		return false
	end

	local curammo = get_totals(self.agent)
	local maxammo = 0

	for name, cat in pairs(dctenum.weaponCategory) do
		local pct = curammo[cat] / self.initialammo[cat]
		local fact = self.agent:getFact(factkey(name))

		fact.value.value = pct
		fact.updatetime = timer.getTime()
		maxammo = math.max(maxammo, pct)
	end

	set_has_ammo(maxammo, self.agent)
	self.fired = false
	self.timer:reset()
	self.timer:start()
	return false
end

return AmmoSensor
