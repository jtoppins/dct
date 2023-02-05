-- SPDX-License-Identifier: LGPL-3.0
--
-- Initializes player slots.

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local dctutils = require("dct.libs.utils")
local vector   = require("dct.libs.vector")
local STM      = require("dct.templates.STM")
local Template = require("dct.templates.Template")
local Region   = require("dct.templates.Region")
local Logger   = dct.Logger.getByName("Systems")

local airbase_id2name_map = nil
if airbase_id2name_map == nil then
	airbase_id2name_map = {}
	for _, ab in pairs(world.getAirbases()) do
		airbase_id2name_map[tonumber(ab:getID())] = ab:getName()
	end
end

local function is_player_group(grp, _, _)
	local isplayer, slotcnt = dctutils.isplayergroup(grp)

	if isplayer and slotcnt > 1 then
		Logger:warn("DCT requires 1 slot groups. Group '%s' of "..
			    "type a/c (%s) has more than one player slot.",
			    grp.name, grp.units[1].type)
	end
	return isplayer
end

local function closest_airbase(airbase, data)
	local a = vector.Vector2D(airbase:getPoint())
	local dist = vector.distance(data.player, a)

	if dist < data.closestdist then
		data.closestdist = dist
		data.airbasename = airbase:getName()
	end
end

local function airbase_name(grp)
	assert(grp, "value error: grp cannot be nil")
	local id

	for _, name in ipairs({"airdromeId", "helipadId", "linkUnit"}) do
		id = grp.data.route.points[1][name]
		if id ~= nil then
			return airbase_id2name_map[id]
		end
	end

	local vol = {
		id = world.VolumeType.SPHERE,
		params = {
			point = grp.data.route.points[1],
			radius = 700,
		},
	}
	local data = {
		player = vector.Vector2D(grp.data.route.points[1]),
		closestdist = 800,
		airbasename = false,
	}

	world.searchObjects(Object.Category.BASE, vol, closest_airbase, data)
	if data.airbasename == false then
		return nil
	end
	return data.airbasename
end

local function airbase_parking_id(grp)
	assert(grp, "value error: grp cannot be nil")
	local wp = grp.data.route.points[1]
	if wp.type == AI.Task.WaypointType.TAKEOFF_PARKING or
	   wp.type == AI.Task.WaypointType.TAKEOFF_PARKING_HOT then
		return grp.data.units[1].parking
	end
	return nil
end

local PlayerSlots = class("PlayerSlots")
function PlayerSlots:postinit()
	local cnt = 0
	local theater = dct.Theater.singleton()
	local assetmgr = theater:getAssetMgr()
	local region = Region({
		["name"] = "__builtin",
		["priority"] = 1000,
		["builtin"] = true,
	})

	theater:getRegionMgr():addRegion(region)
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
						  env.getValueDictByKey,
						  is_player_group,
						  nil)
		for _, grp in ipairs(grps) do
			local name = grp.data.name
			local side = coalition.getCountryCoalition(grp.countryid)
			local airbase = airbase_name(grp)
			local tpl = Template({
				["objtype"]   = "player",
				["name"]      = name,
				["coalition"] = utils.getkey(coalition.side,
							     side),
				["cost"]      = theater:getTickets():
						getPlayerCost(side),
				["desc"]      = "Player group",
				["location"]  = { ["x"] = grp.data.x,
						  ["y"] = grp.data.y, },
				["tpldata"]   = { [1] = grp, },
				["groupId"]   = grp.data.groupId,
				["squadron"]  = name:match("(%w+)(.+)"),
				["airbase"]   = airbase,
				["parking"]   = airbase_parking_id(grp),
				["overwrite"] = false,
			})

			region:addTemplate(tpl)
			assetmgr:add(tpl:createObject())
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("PlayerSlots:__init(); found %d slots", cnt))
end

return PlayerSlots
