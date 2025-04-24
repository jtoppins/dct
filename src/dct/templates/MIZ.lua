-- SPDX-License-Identifier: LGPL-3.0

--- Handles loading a mission table and deals with reading the zip file and
-- extracting the mission table from the zip.
-- @classmod dct.templates.MIZ

require("libs")
local utils = libs.utils
local class = libs.classnamed
local Logger = require("dct.libs.Logger")
local vector = require("dct.libs.vector")
local extract = require("dct.templates.extract")

--- Process category table and extract all defined groups.
local function processCategory(grplist, cattbl, cntryid, dcscategory, logger)
	if type(cattbl) ~= 'table' or cattbl.group == nil then
		return
	end

	for _, grp in ipairs(cattbl.group) do
		if dcscategory == Unit.Category.STRUCTURE then
			local dead = grp.dead
			grp = utils.deepcopy(grp.units[1])
			grp.dead = dead
		end

		local grptbl = {
			["data"]      = grp,
			["countryid"] = cntryid,
			["category"]  = dcscategory,
		}

		if grplist[grptbl.data.name] ~= nil then
			logger:error("duplicate groups named '%s' replacing with newest",
				     grptbl.data.name)
		end
		grplist[grptbl.data.name] = grptbl
	end
end

--- Convert a mission zone table to a lua table where each
-- property key,value pair is now a field in a props table.
local function zone2tbl(zonetbl)
	local zone = {}
	zone.name = zonetbl.name
	zone.type = zonetbl.type
	zone.point = vector.Vector2D(zonetbl)
	zone.radius = zonetbl.radius
	zone.verticies = zonetbl.verticies
	zone.id = zonetbl.zoneId
	zone.heading = zonetbl.heading
	zone.props = {}
	zone.groups = {}

	for _, prop in ipairs(zonetbl.properties) do
		if zone.props[prop.key] == nil then
			zone.props[prop.key] = prop.value
		else
			if type(zone.props[prop.key]) == "table" then
				table.insert(zone.props[prop.key], prop.value)
			else
				local oldval = zone.props[prop.key]
				zone.props[prop.key] = {}
				table.insert(zone.props[prop.key], oldval)
				table.insert(zone.props[prop.key], prop.value)
			end
		end
	end
	return zone
end

--- Represents a mission table
local MIZ = class("miz")

--- maps category to the table entry in a mission table.
-- The keys are the mission table entries in lower case and the values
-- map the Unit.Category[<key>] keys.
MIZ.categorymap = {
	["HELICOPTER"] = 'HELICOPTER',
	["SHIP"]       = 'SHIP',
	["VEHICLE"]    = 'GROUND_UNIT',
	["PLANE"]      = 'AIRPLANE',
	["STATIC"]     = 'STRUCTURE',
}

--- Load a .miz file into a lua table. It is assumed the mission is zip
-- compressed.
function MIZ.loadfile(zfile)
	local tbl, err = extract(zfile, "mission", "l10n/DEFAULT/dictionary",
				 "warehouses")
	if not tbl then
		return nil, err
	end

	tbl.file = zfile
	local sortie = tbl.dictionary[tbl.mission.sortie]
	if sortie then
		tbl.mission.sortie = sortie
	end
	return MIZ(tbl)
end

--- Constructor.
function MIZ:__init(miztbl)
	self._logger = Logger.getByName("Template")
	self.requiredModules = miztbl.mission.requiredModules
	self.date    = miztbl.mission.date
	self.theatre = miztbl.mission.theatre
	self.sortie  = miztbl.mission.sortie
	self.file    = miztbl.file
	self.zones   = {}
	self.groups  = {}

	self:addZones(miztbl)
	self:addGroups(miztbl)

	self.categorymap = nil
	self.loadfile = nil
end

function MIZ:addZone(zone, file)
	if zone == nil then return end

	if self.zones[zone.name] ~= nil then
		self._logger:error("zone(%s): duplicate zone name in file(%s)",
				   zone.name, tostring(file))
	end
	self.zones[zone.name] = zone
end

--- Get all zones from the mission table.
-- @return table keyed on zone name
function MIZ:addZones(miztbl)
	for _, zonetbl in ipairs(miztbl.mission.triggers.zones) do
		self:addZone(zone2tbl(zonetbl), miztbl.file)
	end
end

--- Get all groups defined in `miztbl`.
-- @return table keyed on group names.
function MIZ:addGroups(miztbl)
	for _, coa_data in pairs(miztbl.mission.coalition) do
		for _, cntrytbl in ipairs(coa_data.country) do
			for cat, unitcat in pairs(MIZ.categorymap) do
				processCategory(self.groups,
					cntrytbl[string.lower(cat)],
					cntrytbl.id,
					Unit.Category[unitcat],
					self._logger)
			end
		end
	end
end

return MIZ
