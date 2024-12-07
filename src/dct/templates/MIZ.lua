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

--- Convert a mission zone table to a lua table with each
-- property key,value pair is now a field in the table.
local function zone2tbl(zonetbl)
	local zone = {}
	zone.name = zonetbl.name
	zone.point = vector.Vector2D(zonetbl.x, zonetbl.y)
	zone.radius = zonetbl.radius

	for _, prop in ipairs(zonetbl.properties) do
		zone[prop.key] = prop.value
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
end

--- Get all zones from the mission table.
-- @return table keyed on zone name
function MIZ:addZones(miztbl)
	for _, zonetbl in ipairs(miztbl.mission.triggers.zones) do
		local z = zone2tbl(zonetbl)

		if self.zones[z.name] ~= nil then
			self._logger:error("zone(%s): duplicate zone name in file(%s)",
					   z.name, miztbl.file)
		end
		self.zones[z.name] = z
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
