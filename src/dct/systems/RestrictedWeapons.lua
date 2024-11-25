-- SPDX-License-Identifier: LGPL-3.0

--- Restricted Weapons.
-- Implements a weapon point buy system to limit player payloads.
-- Assumes a single player slot per group and the player is the first
-- slot.
-- @module dct.systems.RestrictedWeapons

require("libs")

local class         = libs.classnamed
local utils         = libs.utils
local dctenum       = require("dct.enum")
local AmmoCount     = require("dct.libs.AmmoCount")
local Check         = require("dct.libs.Check")
local CheckPerEntry = require("dct.libs.CheckPerEntry")
local Command       = require("dct.libs.Command")
local System        = require("dct.libs.System")
local DCTEvents     = require("dct.libs.DCTEvents")
local WS            = require("dct.agent.worldstate")
local builtin_restrictions = require("dct.systems.data.restrictedweapons")

-- TODO: listen for birth events and post this message to any player agents
local notifymsg =
	"Please read the loadout limits in the briefing and "..
	"use the F10 Menu to validate your loadout before departing."

local function validate_restrictions(cfg, tbl)
	local CheckRestrictedWeapons = CheckPerEntry(nil, {
		["cost"] = {
			["nodoc"] = true,
			["type"] = Check.valuetype.INT,
		},
		["category"] = {
			["nodoc"] = true,
			["type"] = Check.valuetype.TABLEKEYS,
			["values"] = AmmoCount.weaponCategory,
		},
	})

	local ok, entrykey, msg = CheckRestrictedWeapons:check(tbl)
	if not ok then
		error(string.format("entry(%s) %s; file: %s",
			entrykey, msg, cfg.file))
	end
	return tbl
end

--- validates payload limits configuration
-- This is per airframe with a "default" entry in case an airframe is
-- not defined. The default is unlimited.
local function validate_payload_limits(cfg, tbl)
	local newlimits = {}

	for planetype, limits in pairs(tbl) do
		newlimits[planetype] = {}
		local tmptbl = {}

		for wpncat, val in pairs(limits) do
			local w = AmmoCount.weaponCategory[string.upper(wpncat)]

			if w == nil then
				error(string.format(
					"invalid weapon category '%s' - "..
					"plane type %s; file: %s",
					wpncat, planetype, cfg.file))
			end
			tmptbl[w] = val
		end
		utils.mergetables(newlimits[planetype], tmptbl)
	end
	return newlimits
end

local clsname = "RestrictedWeapons"

--- Restricted Weapons system.
-- Implements a loadout point buy system to limit player loadouts.
-- Assumes a single player slot per group and it is the first slot.
-- @type RestrictedWeapons
local RestrictedWeapons = class(clsname, System, DCTEvents)

--- Enable this system by default.
RestrictedWeapons.enabled = true

--- Check if a Player's payload is valid.
-- @tparam Agent agent the agent (usually a player) to check the
--   payload of.
function RestrictedWeapons.check(agent)
	local key = "checkpayload_msg"

	if agent:WS():get(WS.ID.INAIR).value == true then
		post_msg(agent, key,
			"Payload check is only allowed when landed at "..
			"a friendly airbase")
		return
	end

	local rstctdwpns = dct.Theater.singleton():getSystem(clsname)
	local ok, totals = rstctdwpns:validate(agent)
	local msg = rstctdwpns:summary(totals)
	local header

	if ok then
		header = "Valid loadout, you may depart. Good luck!\n\n"
	else
		header = "You are over budget! Re-arm before departing, "..
			 "or you will be punished!\n\n"
	end
	post_msg(agent, key, header..msg)
end

--- Constructor.
function RestrictedWeapons:__init(theater)
	System.__init(self, theater, System.PRIORITY.ADDON)
	DCTEvents.__init(self)
	self._restrictedweapons = builtin_restrictions
        self._payloadlimits = {}
        self._enforcePolicyDelay = 15

	self:_overridehandlers({
		[world.event.S_EVENT_TAKEOFF] = self.handlePlayerTakeoff,
	})
end

--- Initialize the system.
function RestrictedWeapons:initialize()
        self._assetmgr = self._theater:getSystem(System.SYSTEMALIAS.ASSETMGR)
	local basepath = utils.join_paths(self._theater:getPath(), "settings")
	local config = {}
	local cfgs = {
		{
			["name"] = "restrictedweapons",
			["file"] = utils.join_paths(basepath,
						    "restrictedweapons.cfg"),
			["cfgtblname"] = "restrictedweapons",
			["validate"] = validate_restrictions,
			["env"] = {
				["INFCOST"] = AmmoCount.WPNINFCOST,
			},
		}, {
			["name"] = "payloadlimits",
			["file"] = utils.join_paths(basepath,
						    "payloadlimits.cfg"),
			["cfgtblname"] = "payloadlimits",
			["validate"] = validate_payload_limits,
		}
	}

	utils.readconfigs(cfgs, config)
	utils.mergetables(self._restrictedweapons, config.restrictedweapons)
	utils.mergetables(self._payloadlimits, config.payloadlimits)

	local menusys = self._theater:getSystem(System.SYSTEMALIAS.MENU)
	if menusys ~= nil then
		local menu = menusys:getMenu(menusys.menutype.GROUNDCREW)
		menu:addRqstCmd("Check Payload", self.check)
	end
end

--- Start the system.
function RestrictedWeapons:start()
	self._theater:addObserver(self.onDCTEvent, self,
				  self.__clsname..".onDCTEvent")
end

--- Determine if the initiator of the takeoff event was from a player.
-- If it is a player defer processing the player's payload until
-- off the event hot path.
function RestrictedWeapons:handlePlayerTakeoff(event)
        local asset = self._assetmgr:getAssetByDCSObject(
                                        event.initiator:getName())

        if asset == nil or asset.type ~= dctenum.assetType.PLAYER then
                return
        end

        self._theater:queueCommand(Command(self._enforcePolicyDelay,
                                           self.__clsname..".enforcePolicy",
                                           self.enforcePolicy,
                                           self, asset.name))
end

--- Validates the unit's payload is valid.
-- @tparam Unit unit DCS Unit object.
-- @tparam table limits limits table to use to determine if the payload
--   is valid.
-- @treturn bool true if payload is valid
-- @treturn AmmoCount total cost per category of the payload, also
--   includes the max allowed for the airframe
function RestrictedWeapons:_validate(unit, limits)
	local total = AmmoCount(limits)
	total:add(unit)
	return total:isValid(), total
end

--- Validates the player's payload is valid.
-- @tparam Agent player DCT Agent object of type player.
function RestrictedWeapons:validate(player)
        local unit = Group.getByName(player.name):getUnit(1)
        local planetype = unit:getTypeName()

	return self:_validate(unit, self._payloadlimits[planetype])
end

--- Build the cost summary header.
-- @tparam AmmoCount costs payload totals table
-- @treturn string payload summary header
function RestrictedWeapons:_buildHeader(costs)
	local msg = "== Payload Summary:"

	for desc, cat in pairs(AmmoCount.weaponCategory) do
		if costs.totals[cat].current < AmmoCount.WPNINFCOST then
			msg = msg..string.format("\n  %s cost: %.4g / %d",
						 desc,
						 costs.totals[cat].current,
						 costs.totals[cat].max)
		else
			msg = msg..string.format("\n  %s cost: -- / %d",
						 desc,
						 costs.totals[cat].max)
		end
	end
	return msg
end

--- Build the detailed payload report.
-- @tparam table payload the payload list in AmmoCount.
-- @tparam string desc AmmoCount.weaponCategory key
-- @treturn string payload details summary
function RestrictedWeapons:_buildPayloadDetails(payload, desc)
	if next(payload) == nil then
		return ""
	end

	local msg = string.format("\n\n== %s Weapons:", desc)

	for _, wpn in ipairs(payload) do
		msg = msg..string.format("\n  %s\n    ↳ ", wpn.name)
		if wpn.cost == 0 then
			msg = msg..string.format("%d × unrestricted (0 pts)",
						 wpn.count)
		elseif wpn.cost < AmmoCount.WPNINFCOST then
			msg = msg..string.format("%d × %.4g pts = %.4g pts",
				wpn.count, wpn.cost, wpn.count * wpn.cost)
		else
			msg = msg.."Weapon cannot be used in this theater [!]"
		end
	end
	return msg
end

--- Generate a payload summary for the costs table provided.
-- @tparam AmmoCount costs the ammo count table to provide the summary of.
-- @treturn string text string summary of the loadout
function RestrictedWeapons:summary(costs)
	local msg = self:_buildHeader(costs)

	for desc, cat in pairs(AmmoCount.weaponCategory) do
		msg = msg..self:_buildPayloadDetails(
				costs.totals[cat].payload, desc)
	end
	return msg
end

--- Enforce policy for players who violate the weapon restrictions.
function RestrictedWeapons:enforcePolicy(name)
        local asset = self._assetmgr:getAsset(name)

        if asset == nil then
                return
        end

	local ok = self:validate(asset)

        if ok then
                return
        end

        asset:onDCTEvent(dct.event.build.playerKick(kickCode.LOADOUT))
end

return RestrictedWeapons
