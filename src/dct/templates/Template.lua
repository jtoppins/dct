--- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.

local class    = require("libs.namedclass")
local check    = require("libs.check")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.libs.utils")
local STM      = require("dct.templates.STM")
local Logger   = dct.Logger.getByName("Template")

local norenametype = {
	[dctenum.assetType.SQUADRONPLAYER] = true,
	[dctenum.assetType.PLAYERGROUP]    = true,
	[dctenum.assetType.AIRBASE]        = true,
}

-- TODO: setup a respawn attribute

-- TODO: we can classify airdefense sites by the highest radar
-- type the template has. We need this classification for UI
-- reasons. We also need it for the air defense manager as
-- depending on strategy we only want EWRs to search.
--
-- TODO: create a SAM/EWR Sensor that iterates over the template on spawn
-- and adds a Fact that is a list of unit names that should be queried
-- for what their radars see

local checkers = {
	require("dct.templates.checkers.CheckCommon")(),
	require("dct.templates.checkers.CheckTpldata")(),
	--require("dct.templates.checkers.CheckAgent")(),
	require("dct.templates.checkers.CheckAirbase")(),
	require("dct.templates.checkers.CheckSquadron")(),
	require("dct.templates.checkers.CheckCoalition")(),
	require("dct.templates.checkers.CheckLocation")(),
}

local function rename(name, regionname, unique)
	local n = name

	if type(regionname) == "string" then
		n = tostring(regionname).."_"..n
	end

	if unique then
		n = n.." #"..dct.Theater.singleton():getcntr()
	end
	return n
end

local function rename_group(grp, regionname, unique)
	if grp.category == dctenum.UNIT_CAT_SCENERY then
		return
	end

	grp.data.name = rename(grp.data.name, regionname, unique)
	for _, v in ipairs(grp.data.units or {}) do
		v.name = rename(v.name, regionname, unique)
	end
end

--- make all group and unit names unique.
local function makeNamesUnique(data)
	for _, grp in ipairs(data or {}) do
		rename_group(grp, nil, true)
	end
end

--- prepend all group and unit names with the region name the Template
-- belongs to.
local function add_region_name_to_objects(data, regionname)
	for _, grp in ipairs(data or {}) do
		rename_group(grp, regionname, false)
	end
end

--- select a location description used in generating mission briefings for
-- players.
local function genLocationMethod()
	local txt = {
		"Reconnaissance elements have located",
		"A recon flight earlier today discovered",
		"We have reason to believe there is",
		"Aerial photography shows that there is",
		"Satellite imaging has found",
		"Ground units operating in the area have informed us of",
	}
	local idx = math.random(1,#txt)
	return txt[idx]
end

--- generate a codename for an asset created from `template`.
local function genCodename(template)
	if template.codename ~= "default codename" then
		return template.codename
	end

	local codenamedb = dct.settings.codenamedb
	local typetbl = codenamedb[template.objtype]

	if typetbl == nil then
		typetbl = codenamedb.default
	end

	local idx = math.random(1, #typetbl)
	return typetbl[idx]
end

--- generate an asset name.
-- An asset must have a unique name or it will not be added to the
-- AssetManager. This function guarantees compliance with this requirement.
--
-- @param template template date used to generate the unique name from
-- @return a predictable unique name
local function genName(template)
	local name = template.name

	if norenametype[template.objtype] == nil then
		name = template.regionname.."_"..template.coalition.."_"..
			template.name
		if template.uniquenames == true then
			name = name.." #"..dct.Theater.singleton():getcntr()
		end
	end
	return name
end

--- Validates user `data` according to the checkers defined in `checkers`.
--
-- @param data data to validate
-- @return bool, true on successful validation with no errors; false otherwise
local function validate(data)
	local copyoptions = {}

	for _, checker in ipairs(checkers) do
		local ok, key, msg = checker:check(data)

		if not ok then
			Logger:error("%s: invalid `%s` %s; file: %s",
				tostring(data.name), tostring(key),
				tostring(msg), tostring(data.filedct))
			return ok
		end

		utils.mergetables(copyoptions, checker:agentOptions())
	end
	utils.mergetables(copyoptions, {["regionname"] = true,})
	data.agentDescKeys = copyoptions
	return true
end

--- @class Template
-- Represents a game template from which one or many game assets can be
-- created.
local Template = class("Template")
function Template:__init(data)
	check.table(data)

	self._valid = validate(data)
	if not self._valid then
		return
	end

	-- TODO: write this classification function, more design is needed
	--classify(data)

	-- remove static functions
	self.fromFile = nil

	-- merge data into template
	utils.mergetables(self, utils.deepcopy(data))
	self._joinedregion = false
end

--- Read the .dct and optionally the .stm files for a given Template into
-- a lua table. Then create a Template object at the same time checking
-- the template's data is valid.
--
-- @param region the region object the Template belongs to
-- @param dctfile the file path of the .dct file describing the template
-- @param stmfile [optional] the file path of the .stm file describing the
--          template
-- @return a Template object
function Template.fromFile(dctfile, stmfile)
	assert(dctfile ~= nil, "dctfile is required")

	local template = utils.readlua(dctfile)
	-- support older templates
	if template.metadata then
		template = template.metadata
	end

	if template.desc == "false" then
		template.desc = nil
	end

	if stmfile ~= nil then
		-- call order matters here as we want items in the dct file
		-- to override items defined in the stm file.
		template = utils.mergetables(
			STM.transform(utils.readlua(stmfile, "staticTemplate")),
			template)
	end
	template.file = nil
	template.filedct = dctfile
	template.filestm = stmfile
	return Template(template)
end

--- class function to generate Template documentation.
function Template.genDocs()
end

--- Create a DCT game object from the template definition.
--
-- @return the object created
function Template:createObject()
	return self:_create(genName(self),
			    self.objtype,
			    self.coalition,
			    self:genDesc(),
			    self)
end

function Template:copyData()
	local copy = utils.deepcopy(self.tpldata)
	if self.uniquenames == true then
		makeNamesUnique(copy)
	end
	return copy
end

--- is the Template valid, a Template can fail validation without killing
-- the game. It is up to the user of the Template to make sure the Template
-- is valid.
function Template:isValid()
	return self._valid
end

function Template:joinRegion(region)
	if self._joinedregion then
		return
	end

	self.regionname = region.name
	self.regionprio = region.priority

	if norenametype[self.objtype] == nil then
		add_region_name_to_objects(self.tpldata, region.name)
	end
	self._joinedregion = true
end

--- Generate the description table from the Template. Is usually given
-- to the asset to store locally.
function Template:genDesc()
	local desc = {}
	for k, _ in pairs(self.agentDescKeys) do
		if type(self[k]) ~= "function" then
			desc[k] = utils.deepcopy(self[k])
		end
	end

	if self.uniquenames == true then
		desc.codename = genCodename(self)
		desc.locationmethod = genLocationMethod()
		makeNamesUnique(desc.tpldata)
	end
	return desc
end

--- Generate mission briefing text from the supplied information
--
-- @param posit position data to use when generating location information
-- @precision how accurate posit is
-- @desc description table from the asset
-- @fmts the format table
function Template:genBriefing(posit, precision, desc, fmts)
	local brief = nil

	if self.desc then
		brief = dctutils.interp(self.desc, {
			["LOCATIONMETHOD"] = desc.locationmethod,
			["LOCATION"] = dctutils.fmtposition(posit, precision,
						fmts.position),
		})
	end
	return brief
end

return Template
