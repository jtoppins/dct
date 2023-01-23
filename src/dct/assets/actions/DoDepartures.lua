-- SPDX-License-Identifier: LGPL-3.0

local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local Timer    = require("dct.libs.Timer")
local WS       = require("dct.assets.worldstate")

-- TODO: think about splitting launch and recovery into different
-- actions. The problem trying to be solved is fundamentally launching
-- and recovering aircraft are parallel processes that we are trying to
-- solve without any state for who is on final, aircraft queued on the
-- taxiways for departure, etc...
-- TODO: what should an airbase do for returning aircraft and their
-- recovery?

--- @classmod LaunchRecover
-- Depart and recover aircraft as part of normal airdrome operations.
local LaunchRecover = require("libs.namedclass")("LaunchRecover", WS.Action)
function LaunchRecover:__init(agent, cost)
	WS.Action.__init(self, agent, cost or 10, {
		-- pre-conditions
		WS.Property(WS.ID.DAMAGED, false),
	}, {
		-- effects
		WS.Property(WS.ID.STANCE, WS.Stance.ATTACKING),
	}, 100)

	self.timer = Timer(60)
end

-- check if we have any departures to do, we only do one departure
-- per run of this function to allow for separation of flights.
function LaunchRecover:doOneDeparture()
	self.agent:debug("TODO: launch one flight")
	-- TODO: search through the airbase's memory and find the next
	-- friendly character who's last update is less than the current
	-- in-game time
end

function LaunchRecover:enter()
	self.timer:reset()
	self.timer:start()
	self:doOneDeparture()
end

function LaunchRecover:isComplete()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end

	self:doOneDeparture()
	self.timer:reset()
	return false
end

return LaunchRecover
