-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class       = libs.classnamed
local dctenum     = require("dct.enum")
local dctutils    = require("dct.libs.utils")
local Timer       = require("dct.libs.Timer")
local DCTEvents   = require("dct.libs.DCTEvents")
local WS          = require("dct.assets.worldstate")
local UPDATE_TIME = 60

-- TODO: Instead of a squadron being assigned a mission squadrons will
-- pick missions from the commander's list of available missions.

local function isPlayer(asset)
	if asset.type == dctenum.assetType.PLAYER then
		return true
	end
	return false
end

--- @classmod SquadronSensor
-- Represents a Squadron. Tracks and manages players slots associated with
-- this squadron. Since other Agents will need to determine if a squadron
-- is capable of flying sorties the squadron's health will be toggled
-- between DAMAGED and OPERATIONAL based on several factors; aircraft
-- available, the airbase is operational, etc.
local SquadronSensor = class("SquadronSensor", WS.Sensor, DCTEvents)
function SquadronSensor:__init(agent)
	WS.Sensor.__init(self, agent, 50)
	DCTEvents.__init(self)
	self.timer = Timer(UPDATE_TIME)
	self._operstate = false

	self:_overridehandlers({
		[dctenum.event.DCT_EVENT_OPERATIONAL] =
			self.handleAirbaseState,
	})
end

--- Set the agent's ato list for which missions they are allowed to fly.
function SquadronSensor:setATO(flight)
	dctutils.set_ato(self.agent, flight)
end

--- A Squadron is defined to be operational if its health state is
-- operational and it is spawned.
function SquadronSensor:isOperational()
	local health = self.agent:WS():get(WS.ID.HEALTH).value

	return health == WS.Health.OPERATIONAL and self._operstate and
	       self.agent:isSpawned()
end

function SquadronSensor:setup()
	-- TODO: restore airframe stats
end

function SquadronSensor:spawn()
	local allplayers = self.agent:getDescKey("all_players")
	local basedat = self.agent:getDescKey("basedat")

	-- clear all subordinates from the squadron
	self.agent._subordinates = {}

	local assetmgr = dct.Theater.singleton():getAssetMgr()
	for _, asset in pairs(assetmgr:filterAssets(isPlayer)) do
		local assetbase = asset:getDescKey("basedat")
		local isvalid = (basedat == assetbase and
				 self.agent.owner == asset.owner)

		if isvalid and allplayers then
			self.agent:addSubordinate(asset)
			self:setATO(asset)
		elseif isvalid and
		       self.agent.name == asset:getDescKey("squadron") then
			self.agent:addSubordinate(asset)
			self:setATO(asset)
		end
	end
end

function SquadronSensor:spawnPost()
	self.timer:reset()
	self.timer:start()
end

--- By definition a despawned airbase cannot have an operational tower
function SquadronSensor:despawnPost()
	self.timer:stop()
end

function SquadronSensor:handleAirbaseState(event)
	if event.initiator.name ~= self.agent:getDescKey("basedat") then
		return
	end

	self._operstate = event.state

	local assetmgr = dct.Theater.singleton():getAssetMgr()

	for name, _ in self.agent:iterateSubordinates() do
		local child = assetmgr:getAsset(name)

		if child then
			child:onDCTEvent(event)
		end
	end
end

--[[
function SquadronSensor:update()
	self.timer:update()
	if not self.timer:expired() then
		return false
	end


	self.timer:reset()
	self.timer:start()
	return false
end
--]]

return SquadronSensor
