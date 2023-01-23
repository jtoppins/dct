-- SPDX-License-Identifier: LGPL-3.0

local utils      = require("libs.utils")
local containers = require("libs.containers")
local dctenum    = require("dct.enum")
local dctutils   = require("dct.libs.utils")
local Command    = require("dct.libs.Command")
local Memory     = require("dct.libs.Memory")
local Logger     = dct.Logger.getByName("Commander")

local invalidXpdrTbl = {
	["7700"] = true,
	["7600"] = true,
	["7500"] = true,
	["7400"] = true,
}

--- Defines a side's strategic theater commander.
local Commander = require("libs.namedclass")("Commander", Memory)
function Commander:__init(theater, side)
	Memory.__init(self)
	self.theater      = theater
	self.owner        = side
	self.missions     = {}
	self.sensors      = {}
	self.aifreq       = 30

	-- Cache valid mission IDs in random order
	self.airMissionIds = {}
	for i = 0, 63 do
		table.insert(self.airMissionIds,
			     math.random(#self.airMissionIds + 1), i)
	end

	theater:queueCommand(self.aifreq, Command(
		"Commander("..tostring(self.owner)..").update",
		self.update, self))
	theater:getAssetMgr():addObserver(self.onDCTEvent, self,
		"Commander("..tostring(self.owner)..").onDCTEvent")
end

--[[
local function handle_asset_dead(cmdr, event)
	cmdr.targets[event.initiator.name] = nil
end

local function handle_asset_add(cmdr, event)
	local asset = event.initiator

	if dctutils.isenemy(cmdr.owner, asset.owner) and
	   dctenum.assetClass.STRATEGIC[asset.type] ~= nil then
		cmdr.targets[asset.name] = asset.type
	end
end

function Commander:assethandler(event)
	local handlers = {
		[dctenum.event.DCT_EVENT_DEAD] = handle_asset_dead,
		[dctenum.event.DCT_EVENT_ADD_ASSET] = handle_asset_add,
	}

	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end
--]]

--- Handle DCS and DCT events sent to the Commander
function Commander:onDCTEvent(event)
	dctutils.foreach_call(self.sensors, ipairs, "onDCTEvent", event)
end

function Commander:update(time)
	for _, sensor in ipairs(self.sensors) do
		if type(sensor.update) == "function" and
		   sensor:update(time) then
			break
		end
	end

	return self.aifreq
end

--- return the Mission object identified by the id supplied.
function Commander:getMission(id)
	return self.missions[id]
end

-- start tracking a given mission internally
function Commander:addMission(mission)
	self.missions[mission:getID()] = mission
end

-- remove the mission identified by id from the commander's tracking
function Commander:removeMission(id)
	self.missions[id] = nil
end

return Commander

-- TODO:
-- Each side's Commander is responsible for general progression of the
-- campaign for the given side. A commander has regions it is responsible
-- for and some regions may have assets that provide supply resources
-- while other assets my be valuable and do not want to be lost.
--
-- Resource Types:
--  * tickets - once a side's ticket pool is zero it looses, tickets
--    represent a dual purpose, the ability to spawn tactical units
--    as well as home support once tickets go below zero the side looses.
--  * supply - represents the capacity to repair or rearm, drives building
--    things like FARPs or repairing/resupplying SAM sites
--
-- Asset Types:
--  * generators - assets that create new tactical Agents to be used in
--    combat. Examples of generators might be squadrons or division HQs.
--    All generator assets require a spawner asset.
--    All generator assets should be able to provide how many new tactical
--    units (flow) they can spawn based on the resource they have available.
--    i.e. a squadron only can sortie 10 flights of aircraft, so its max
--    flow is 10. This can vary a sorties are flown, 3 current sorties being
--    flown so the current flow is 7.
--  * spawners - take as input templates and create new Agents from these
--    templates. Examples of spawners are airbase, CV, off-map airbase,
--    FOB, FARP, etc.
--
-- There are several general actions the commander can take:
--  * attack
--    - search is considered an action of attack because it helps in finding
--      new things to attack.
--  * defend
--  * resupply
--
-- --- maybe not this VVVV
--  Missions have the ability to create new missions, example: the air
--  defense mission in its update function could generate CAP missions
--  if the local airspace seems like it isn't protected enough.
-- --- maybe nor this ^^^^
--
-- GOAP strategic commander AI:
-- * Actions create Mission objects, the set of actions a commander has
--   available to it are simply the ATO lists of generators
-- * Goals general goals could be; attack, defend, resupply, buildup
-- * Sensors things like an IADS manager, sensors adjust tables and
--   drive selection of current goal the commander works toward
--
-- World State:
-- * friendlies_lost - simple moving average over X period
-- * enemies_killed - simple moving average over X period
-- * supply
-- * tickets
--
-- Per Region data:
-- * ground_strength
-- * airdefense_strength
-- * sea_strength
-- * detected_enemy_ground_strength
-- * detected_enemy_airdefense_strength
-- * detected_enemy_sea_strength
--
--
-- THOUGHT: Each region could have a region world state
-- Note: To allow for players to come an go the action set needs to be
--       reevaluated periodically and updated.
--
-- Commander's basic responsibilities:
--  * respond to Agent requests (requests for resupply, request for mission)
--  * determine where the front line(s) are
--  * determine distribution of resources
--
--  TODO: modify the Agent in the MissionSensor to request a new mission
--  if the Agent is not assigned a mission.
--  The thought is let Agents (player & AI) request a specific type of
--  mission then the Commander has a common pathway for mission assignment.
--
--  request air defense mission:
--  player requests support:
--
-- Notes from C&C House AI
-- House only operates in 5 states:
--  * buildup
--  * broke
--  * threatened
--  * attacked
--  * endgame
--
-- Different strategies are only valid for a given state. These strategies
-- specify what buildings will be prioritized and which missions will be
-- assigned to units. The following are all available strategies:
--  * build_power
--  * build_defense
--  * build_income
--  * fire_sale
--  * build_engineer
--  * build_offense
--  * build_money
--  * raise_power
--  * lower_power
--  * attack
--
-- In red alert unit can have a fear state, which is scaled from none, anxious,
-- scared, and max. With units becoming more scared based on health being
-- consistently lost, as well as what class they are as each have different
-- thresholds. When scared unit become unresponsive.
--
-- Also the house has an IQ value which determines if the house AI has access
-- to various actions or features.
