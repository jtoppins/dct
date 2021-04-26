--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Weapons impact tracking system
--]]

local class    = require("libs.namedclass")
local dctutils = require("dct.utils")
local vector   = require("dct.libs.vector")
local Logger   = require("dct.libs.Logger").getByName("System")

-- Only units that are not air defence and are firing
-- weapons with HE warheads are considered
local function isWpnValid(event)
	if event.initiator:hasAttribute("Air Defence") then
		return false
	end

	local wpndesc = event.weapon:getDesc()
	local allowedmsltypes = {
		[Weapon.MissileCategory.CRUISE] = true,
		[Weapon.MissileCategory.OTHER]  = true,
	}
	if wpndesc.category == Weapon.Category.MISSILE and
	   allowedmsltypes[wpndesc.missileCategory] == nil then
	   return false
	end

	if wpndesc.warhead.type ~= Weapon.WarheadType.HE then
		return false
	end
	return true
end

local DCTWeapon = class("DCTWeapon")
function DCTWeapon:__init(wpn, initiator)
	self.start_time  = timer.getTime()
	self.timeout     = false
	self.lifetime    = 300 -- weapons only "live" for 5 minutes
	self.weapon      = wpn
	self.type        = dctutils.trimTypeName(wpn:getTypeName())
	self.shootername = initiator:getName()
	self.desc        = wpn:getDesc()
	self.impactpt    = nil
	self:update(self.start_time, .5)
end

function DCTWeapon:exist()
	return self.weapon:isExist() and not self.timeout
end

function DCTWeapon:hasImpacted()
	return self.impactpt ~= nil
end

function DCTWeapon:getDesc()
	return self.desc
end

function DCTWeapon:getImpactPoint()
	return self.impactpt
end

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

local LOOKAHEAD = 2
local WeaponsTracker = class("WeaponsTracker")
function WeaponsTracker:__init(theater)
	self.updatefreq = 0.1
	self.lookahead = self.updatefreq * LOOKAHEAD
	self.trackedwpns = {}
	self._theater = theater
	theater:addObserver(self.event, self, self.__clsname..".event")
	timer.scheduleFunction(self.update, self,
		timer.getTime() + self.updatefreq)
end

function WeaponsTracker:_update(time)
	local tstart = os.clock()
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
		self._theater:notify(dctutils.buildevent.impact(wpn))
	end
	Logger:warn(string.format("'%s' exec time: %5.2fms",
		self.__clsname..".update", (os.clock()-tstart)*1000))
end

function WeaponsTracker:update(time)
	local errhandler = function(err)
		Logger:error("protected call - "..tostring(err).."\n"..
			debug.traceback())
	end
	local pcallfunc = function()
		self:_update(time)
	end

	xpcall(pcallfunc, errhandler)
	return time + self.updatefreq
end

function WeaponsTracker:event(event)
	if not (event.id == world.event.S_EVENT_SHOT and
	   event.weapon and event.initiator) then
		return
	end

	if not isWpnValid(event) then
		Logger:debug(string.format("%s - weapon not valid "..
			"typename: %s; initiator: ", self.__clsname,
			event.weapon:getTypeName(),
			event.initiator:getName()))
		return
	end
	self.trackedwpns[event.weapon.id_] = DCTWeapon(event.weapon,
		event.initiator)
end

return WeaponsTracker
