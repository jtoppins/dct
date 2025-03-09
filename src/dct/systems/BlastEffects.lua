-- SPDX-License-Identifier: LGPL-3.0

--- Weapon blasteffect and enhacement system.
-- The system;
-- 1. Reads in the built-in correction table and provides a method
--    to apply additional corrections.
-- 2. Acts as a central store for weapon corrections. Other systems
--    can query the Theater instance and if this system is enabled
--    a reference can be obtained.
-- 3. Listens for DCT impact events and triggers enhanced explosions
--    based on the weapon that generated the impact.
-- 4. Track impacts for replay during server restart.
--
-- @classmod dct.systems.BlastEffects

require("libs")

local class   = libs.classnamed
local utils   = libs.utils
local System  = require("dct.libs.System")
local Marshallable = require("dct.libs.Marshallable")
local DCTEvents = require("dct.libs.DCTEvents")
local default_correction_table = require("dct.systems.data.blasteffects")

local BlastEffects = class("BlastEffects", System, Marshallable, DCTEvents)

--- Enable blast effects by default.
BlastEffects.enabled = true

--- Constructor.
function BlastEffects:__init(theater, ageout)
	ageout = ageout or 2
	System.__init(self, theater, System.PRIORITY.ADDON)
	Marshallable.__init(self)
	DCTEvents.__init(self)
	self.impact_age_out = ageout
	self._corrections = utils.deepcopy(default_correction_table)
	self._impacts = {}

	self:_addMarshalNames({
		"_impacts",
	})
	self:_overridehandlers({
		[dct.event.ID.DCT_EVENT_IMPACT] = self.handleImpact,
	})
end

--- Initialize BlastEffects.
-- Load any theater specific settings and any theater specific warhead
-- corrections.
function BlastEffects:initialize()
	local removetbl = {}
	for idx, impact in pairs(self._impacts) do
		for _, power in pairs(impact.powers) do
			trigger.action.explosion(impact.point, power)
		end
		impact.age = impact.age + 1
		if impact.age > self.impact_age_out then
			table.insert(removetbl, idx)
		end
	end

	for i = #removetbl, 1, -1 do
		table.remove(self._impacts, removetbl[i])
	end
	return true
end

--- Registers the event handler with the Theater and does any other startup
-- the system needs.
function BlastEffects:start()
	self._theater:addObserver(self.onDCTEvent, self,
				  self.__clsname..".onDCTEvent")
end

--- Allows a caller to register additional corrections or overwrite existing
-- ones. Any corrections with a negative value will be deleted from the table.
-- @tparam table corrections table keyed on weapon type name with the value
--    the corrected power.
function BlastEffects:overrideCorrections(corrections)
	utils.mergetables(self._corrections, corrections)
	for k, v in pairs(self._corrections) do
		if tonumber(v) < 0 then
			self._corrections[k] = nil
		end
	end
end

--- Gives the corrected mass for the provided weapon type.
-- @tparam string Weapon typename
-- @treturn number corrected TNT mass equivalent in kilograms
-- @return nil if the weapon type does not need correction
function BlastEffects:getCorrectedPower(wpntypename)
	return self._corrections[wpntypename]
end

--- Add an impact to our impact tracking list.
function BlastEffects:addImpact(point, powers)
	local impact = {
		["point"] = point,
		["power"] = powers,
		["age"] = 0,
	}
	table.insert(self._impacts, impact)
end

--- Trigger an explosion if the corrected power is greater than the
-- original power.
function BlastEffects:triggerExplosion(point, power, correctedpower)
	if correctedpower ~= nil and correctedpower > power then
		self._logger:debug("  + enhancing explosion: %d",
				   correctedpower)
		trigger.action.explosion(point, correctedpower)
	end
end

--- Event handler for processing DCT impact events.
function BlastEffects:handleImpact(event)
	local correctedpower = self:getCorrectedPower(event.initiator.type)

	self._logger:debug("received impact event: %s fired from %s",
			   event.initiator.type,
			   event.initiator.shootername)
	self:addImpact(event.point, {
		event.initiator.power,
		correctedpower,
	})

	self:triggerExplosion(event.point, event.initiator.power,
			      correctedpower)
end

return BlastEffects
