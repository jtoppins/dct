--- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.

local class    = require("libs.namedclass")
local check    = require("libs.check")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local STM      = require("dct.templates.STM")
local Agent    = require("dct.assets.Agent")
local Logger   = dct.Logger.getByName("Template")

-- TODO: setup a respawn attribute

-- TODO: we can classify airdefense sites by the highest radar
-- type the template has. We need this classification for UI
-- reasons. We also need it for the air defense manager as
-- depending on strategy we only want EWRs to search.
--
-- TODO: create a SAM/EWR Sensor that iterates over the template on spawn
-- and adds a Fact that is a list of unit names that should be queried
-- for what their radars see

-- The order of these checkers matters as some mutate the template data
-- which later checkers rely on.
local checkers = {
	require("dct.templates.checkers.CheckCommon")(),
	require("dct.templates.checkers.CheckAgent")(),
	require("dct.templates.checkers.CheckAirbase")(),
	require("dct.templates.checkers.CheckSquadron")(),
	require("dct.templates.checkers.CheckPlayer")(),
	require("dct.templates.checkers.CheckTpldata")(),
	require("dct.templates.checkers.CheckCoalition")(),
	require("dct.templates.checkers.CheckAircraft")(),
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
	if template.codename ~= dctenum.DEFAULTCODENAME then
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

--- Template
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
	self.genDocs  = nil

	-- merge data into template
	utils.mergetables(self, utils.deepcopy(data))
	self._joinedregion = false
end

--- Read the .dct and optionally the .stm files for a given Template into
-- a lua table. Then create a Template object at the same time checking
-- the template's data is valid.
--
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
-- Generate markdown styled documentation for all options a campaign
-- designer can use to specify a template.
function Template.genDocs()
	local Checker = require("dct.templates.checkers.Check")
	local header = [[
# Template Attributes

Listing of all template attributes that are either automatically determined
from the template file or directly specified in the .dct file.

Most attributes can be modified event after an asset has been generated
from its template. Meaning campaign progression can be saved but, for example,
the target description of a given template is modified before the saved
campaign is loaded. This target description change will be reflected in
the in-game mission briefing when the campaign is loaded from the save.
However, if an attribute specifies `agent: true` this means that once the
asset has been generated this setting cannot be changed by modifying the
underlying template and the value is fixed for the lifetime of that asset.

Additionally, most attributes are not required and when not provided
reasonable defaults based on template type, composition, and other factors
will be considered when selecting the default.
]]

	Checker.genDocs(header, checkers)
end

--- Create a DCT game object from the template definition.
--
-- @return the object created
function Template:createObject()
	return Agent.create(self:genName(),
			    self.objtype,
			    self.coalition,
			    self:genDesc())
end

--- Generate any subordinate assets that are defined in the template.
--
-- @param region the Region instance to look up template names
-- @param assetmgr the AssetManager instance to store generated assets
-- @param parent asset object
function Template:generate(region, assetmgr, parent)
	for name, _ in pairs(self.subordinates) do
		local tpl = region:getTemplateByName(name)

		if tpl then
			local sub = tpl:createObject()

			parent:addSubordinate(sub)
			-- have subordinate observe the parent
			parent:addObserver(sub.onDCTEvent, sub, sub.name)
			assetmgr:add(sub)
			tpl:generate(region, assetmgr, sub)
		end
	end
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

	if self.rename then
		add_region_name_to_objects(self.tpldata, region.name)
	end
	self._joinedregion = true
end

--- generate an asset name.
-- An asset must have a unique name or it will not be added to the
-- AssetManager. This function guarantees compliance with this requirement.
--
-- @param template template date used to generate the unique name from
-- @return a predictable unique name
function Template:genName()
	local name = self.name

	if self.rename then
		name = self.regionname.."_"..self.coalition.."_"..self.name
		if self.uniquenames == true then
			name = name.." #"..dct.Theater.singleton():getcntr()
		end
	end
	return name
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

return Template
