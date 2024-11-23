-- SPDX-License-Identifier: LGPL-3.0

--- Weapons impact tracking system.
-- The system;
-- * tracks a weapon to impact
-- * emits an impact event to DCS
-- @classmod dct.systems.WeaponImpactTracker

local myos = require("os")
require("libs")
local class     = libs.classnamed
local dctutils  = require("dct.libs.utils")
local vector    = require("dct.libs.vector")
local System    = require("dct.libs.System")
local DCTEvents = require("dct.libs.DCTEvents")
local LOOKAHEAD = 2 -- scales update rate to determine how many seconds
		    -- ahead to predict a weapon's impact point

--- DCTWeapon.
-- Is a representation of a DCS Weapon object.
-- @type DCTWeapon
local DCTWeapon = class("DCTWeapon")

--- Constructor.
function DCTWeapon:__init(wpn, initiator)
	self.start_time  = timer.getTime()
	self.timeout     = false
	self.lifetime    = 300 -- weapons only "live" for 5 minutes
	self.weapon      = wpn
	self.type        = dctutils.trimTypeName(wpn:getTypeName())
	self.shootername = initiator:getName()
	self.desc        = wpn:getDesc()
	self.power       = self:getWarheadPower()
	self.impactpt    = nil
	self:update(self.start_time, .5)
end

--- Does the DCS weapon object still exist in the game world?
-- A DCTWeapon is considered to 'exist' if it has not taken too long to
-- impact something and the DCS Weapon object still exists.
-- @treturn bool true if the weapon still exists.
function DCTWeapon:exist()
	return self.weapon:isExist() and not self.timeout
end

--- @treturn bool true if the Weapon is believed to have impacted something.
function DCTWeapon:hasImpacted()
	return self.impactpt ~= nil
end

--- Provides the DCS Weapon description table.
-- @treturn table Weapon description.
function DCTWeapon:getDesc()
	return self.desc
end

local warheadtypes = {
	[Weapon.WarheadType.AP] = "mass",
	[Weapon.WarheadType.HE] = "explosiveMass",
	[Weapon.WarheadType.SHAPED_CHARGE] = "shapedExplosiveMass",
}

--- Gets the warhead's explosive power.
-- @treturn number the mass of the explosive used in the warhead.
function DCTWeapon:getWarheadPower()
	return self.desc.warhead[warheadtypes[self.desc.warhead.type]]
end

--- Get the impact point of where DCT believes the weapon intersected
-- with the group or was deleted by the game.
-- @treturn Vec3 impact point
function DCTWeapon:getImpactPoint()
	return self.impactpt
end

--- Update the weapon's state.
-- @tparam number time current game time step
-- @tparam number lookahead seconds to predict the weapon's future
--         position
function DCTWeapon:update(time, lookahead)
	assert(time, "value error: time must be a non-nil value")
	if not self:exist() then
		return
	end

	local pos = self.weapon:getPosition()

	if time - self.start_time > self.lifetime then
		self.timeout = true
	end

	self.pos  = vector.Vector3D(pos.p)
	self.dir  = vector.Vector3D(pos.x)
	self.vel  = vector.Vector3D(self.weapon:getVelocity())

	-- search lookahead seconds into the future
	self.impactpt = land.getIP(self.pos:raw(),
	                           self.dir:raw(),
	                           self.vel:magnitude() * lookahead)
end

--- WeaponImpactTracker.
-- Tracks DCS Weapon objects to impact. Only weapons conforming to
-- isWpnValid will be tracked. Will emit a DCT impact event to all
-- of DCS upon impact detection.
-- @type WeaponImpactTracker
local WeaponImpactTracker = class("WeaponImpactTracker", System, DCTEvents)

--- Enable weapon tracking by default.
WeaponImpactTracker.enabled = true

--- Constructor.
function WeaponImpactTracker:__init(theater)
	System.__init(self, theater, System.SYSTEMORDER.WPNIMPACT)
	DCTEvents.__init(self)
	self.updatefreq = 0.1
	self.lookahead = self.updatefreq * LOOKAHEAD
	self.trackedwpns = {}

	self:_overridehandlers({
		[world.event.S_EVENT_SHOT] = self.handleShot,
	})
end

function WeaponImpactTracker:initialize()
end

function WeaponImpactTracker:start()
	self._theater:addObserver(self.onDCTEvent, self,
				  self.__clsname..".onDCTEvent")
	timer.scheduleFunction(self.update, self,
		timer.getTime() + self.updatefreq)
end

local allowedmsltypes = {
	[Weapon.MissileCategory.CRUISE] = true,
	[Weapon.MissileCategory.OTHER]  = true,
}

--- Only DCS Weapon objects where this function returns true will be
-- considered. Only consider Weapons not fired from air defence units
-- and have HE warheads. This is a method so that mission builders
-- can override this function if they wish to customize which weapons
-- should be tracked.
-- @param event A DCS Shot event.
-- @treturn bool true if the weapon should be tracked.
function WeaponImpactTracker:isWpnValid(event)
	if event.initiator:hasAttribute("Air Defence") then
		return false
	end

	local wpndesc = event.weapon:getDesc()
	if wpndesc.category == Weapon.Category.MISSILE and
	   allowedmsltypes[wpndesc.missileCategory] == nil then
		return false
	end

	if wpndesc.warhead == nil or
	   wpndesc.warhead.type ~= Weapon.WarheadType.HE then
		return false
	end
	return true
end

--- Real update function run in protected context. Will update each tracked
-- weapon and emit events for each weapon that has been determined to have
-- impacted something.
function WeaponImpactTracker:_update(time)
	local tstart = myos.clock()
	local impacts = {}
	for id, wpn in pairs(self.trackedwpns) do
		wpn:update(time, self.lookahead)
		if wpn:hasImpacted() then
			table.insert(impacts, wpn)
			self.trackedwpns[id] = nil
		elseif not wpn:exist() then
			self.trackedwpns[id] = nil
		end
	end

	for _, wpn in pairs(impacts) do
		world.onEvent(dct.event.build.impact(wpn))
	end

	if dct.settings.server.profile then
		self._logger:debug("'%s.update' exec time: %5.2fms",
			self.__clsname, (myos.clock()-tstart)*1000)
	end
end

--- Update function. Calls the real update function in a protected context.
function WeaponImpactTracker:update(time)
	local ok, err = pcall(self._update, self, time)

	if not ok then
		dctutils.errhandler(err, self._logger)
	end
	return time + self.updatefreq
end

--- Listens for DCS Shot events and tracks weapons the system is
-- interested in according to isWpnValid.
function WeaponImpactTracker:handleShot(event)
	if not self:isWpnValid(event) then
		self._logger:debug("weapon not valid typename: %s; initiator: %s",
			self.__clsname,
			event.weapon:getTypeName(),
			event.initiator:getName())
		return
	end
	self.trackedwpns[event.weapon.id_] = DCTWeapon(event.weapon,
						       event.initiator)
end

return WeaponImpactTracker
