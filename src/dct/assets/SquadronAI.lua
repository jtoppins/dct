--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an AISquadron.
--
-- AISquadron<Squadron>:
--   generates additional assets (flights), tracks the state of an
--   aircraft squadron
--]]

local class = require("libs.namedclass")
local Squadron = require("dct.assets.Squadron")

local function processGroup(sqdn, grp)
	if grp.units == nil then
		sqdn._logger:error(string.format("aircraft group(%s), "..
			"no units defined", grp.name))
		return
	end
	if sqdn.planedata.type ~= nil and
	   sqdn.planedata.type ~= grp.units[1].type then
		sqdn._logger:info(string.format("aircraft group(%s), "..
			"plane type not the same, skipping",
			grp.name))
		return
	end

	local unit = grp.units[1]
	if sqdn.plandata.type == nil then
		sqdn.plandata.type = unit.type
		sqdn.plandata.livery = unit.livery_id
		sqdn.plandata.callsign = unit.callsign
	end

	local tasktype = grp.task
	if sqdn.planedata.payloads.default == nil then
		tasktype = "default"
	end

	sqdn.planedata.payloads[tasktype] = {}
	sqdn.planedata.payloads[tasktype].hardpoint_racks =
		unit.hardpoint_racks
	sqdn.planedata.payloads[tasktype].payload = unit.payload
end

local function getPlaneInfo(sqdn, tpldata)
	assert(tpldata ~= nil, "value error: tpldata cannot be nil")
	local allowed = {
		[Unit.Category.AIRPLANE]   = true,
		[Unit.Category.HELICOPTER] = true,
	}

	for _, grp in ipairs(tpldata) do
		if allowed[grp.category] ~= nil then
			processGroup(sqdn, grp)
		end
	end
end

local SquadronAI = class("SquadronAI", Squadron)
function SquadronAI:__init(template, region)
	Squadron.__init(self, template, region)
	self.plaendata = {}
end

function SquadronAI:_completeinit(template, region)
	Squadron._completeinit(self, template, region)
	assert(self.airbase ~= nil, string.format(
		"%s(%s): no airbase defined and is required",
		self.__clsname, self.name))
	getPlaneInfo(self, template:copyData())
end

function SquadronAI:scheduleFlight(msntype, delay)
	local flight, airbase
	delay = delay or 0
	-- TODO: stuff
	airbase:addFlight(flight, delay)
end

return SquadronAI

--[[
unit definition

 - onboard_num
 - callsign
 - heading
 - payload
 - name
 - x
 - y
 - ?parking_id
 - psi
 - type
 - speed
 - ?parking
 - skill
 - livery_id
 - alt_type
 - ?hardpoint_racks
 - alt

group definition

 - modulation
 - task
 - uncontrolled
 - route
 - units
 - frequency
 - start_time
 - communication
 - name
 - x
 - y
--]]
