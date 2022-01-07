--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Weapon blasteffect and enhacement system
--
-- This listens for DCT impact events and trigger enhanced
-- explosions based on those impact events. This also searches
-- for airbases within the area of the impact and will send
-- a DCT hit event to the airbase if found.
--]]

--[[
-- return the distance in meters from the center of a blast from an
-- explosive charge of mass(kg) that will cause leathal damage to an
-- unarmored target
-- Assume a normalized TNT equivalent mass
-- sources:
--   https://www.fema.gov/pdf/plan/prevent/rms/428/fema428_ch4.pdf
--   https://www.fourmilab.ch/etexts/www/effects/eonw_3.pdf

local function calcRadiusFromMass(mass)
	return math.ceil(11.338 * math.pow(mass, .281))
end
--]]

local class   = require("libs.namedclass")
local dctenum = require("dct.enum")
local Marshallable = require("dct.libs.Marshallable")

local function getCorrectedExplosiveMass(wpntypename)
	return dct.settings.blasteffects[wpntypename]
end

--[[
-- If there is a DCT asset of the same name as the DCS base,
-- notify the DCT asset it has been hit.
--]]
local function handlebase(base, data)
	local asset = data.theater:getAssetMgr():getAsset(base:getName())

	if asset == nil then
		return
	end

	asset:onDCTEvent(data.event)
end

local BlastEffects = class("BlastEffects", Marshallable)
function BlastEffects:__init(theater)
	Marshallable.__init(self)
	self._theater = theater
	self._impacts = {}
	theater:addObserver(self.event, self, self.__clsname..".event")
	self:_addMarshalNames({
		"_impacts",
	})
end

function BlastEffects:_unmarshalpost()
	for idx, impact in pairs(self._impacts) do
		for _, power in pairs(impact.powers) do
			trigger.action.explosion(impact.point, power)
		end
		impact.age = impact.age + 1
		if impact.age > 2 then
			table.remove(self._impacts, idx)
		end
	end
end

function BlastEffects:addImpact(point, powers)
	local impact = {
		["point"] = point,
		["powers"] = powers,
		["age"] = 0,
	}
	table.insert(self._impacts, impact)
end

function BlastEffects:event(event)
	if event.id ~= dctenum.event.DCT_EVENT_IMPACT then
		return
	end

	local power = getCorrectedExplosiveMass(event.initiator.type)
	if power ~= nil then
		trigger.action.explosion(event.point, power)
	end
	self:addImpact(event.point,
		{ power, event.initiator:getWarheadPower() })

	local vol = {
		id = world.VolumeType.SPHERE,
		params = {
			point = event.point,
			radius = 6000, -- allows for > 15000ft runway
		},
	}
	world.searchObjects(Object.Category.BASE, vol, handlebase,
		{
			["event"]   = event,
			["theater"] = self._theater,
		})
end

return BlastEffects
