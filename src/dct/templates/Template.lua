--- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.

require("libs")
local class    = libs.classnamed
local utils    = libs.utils
local dctenum  = require("dct.enum")

-- TODO: create defaults for every attribue so that a template
--       can be generated from a single DCS unit group

-- TODO: setup a respawn attribute

-- TODO: we can classify airdefense sites by the highest radar
-- type the template has. We need this classification for UI
-- reasons. We also need it for the air defense manager as
-- depending on strategy we only want EWRs to search.
--
-- TODO: create a SAM/EWR Sensor that iterates over the template on spawn
-- and adds a Fact that is a list of unit names that should be queried
-- for what their radars see

local group_category_map = {
	[Group.Category.AIRPLANE]   = "AIRPLANE",
	[Group.Category.HELICOPTER] = "HELO",
	[Group.Category.GROUND]     = "GROUND",
	[Group.Category.SHIP]       = "SHIP",
	[Group.Category.TRAIN]      = "INVALID",
}

-- The order of these checkers matters as some mutate the template data
-- which later checkers rely on.
local checkers = nil

local function set_checkers()
	local tbl = {}
	for _, ctor in pairs(dct.templates.checkers) do
		table.insert(tbl, ctor())
	end
	table.sort(tbl)
	return tbl
end

local function tpldata_from_dcsgroup(grp)
	local name = grp:getName()
	local grpcategory = grp:getCategory()
	local tpldata = {}
	local grpdata = {}
	local units = {}

	for idx, unit in pairs(grp:getUnits()) do
		units[idx] = {
			["name"] = unit:getName(),
			["type"] = unit:getTypeName(),
		}
	end

	grpdata.category = grpcategory
	grpdata.data = {}
	grpdata.data.name = name
	grpdata.data.units = units
	table.insert(tpldata, grpdata)
	return tpldata
end

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

local templatemt = {}
function templatemt.__tostring(tpl)
	return string.format("%s.%s", tpl.packname, tpl.name)
end

--- Template.
-- Represents a game template from which one or many game assets can be
-- created.
local Template = utils.override_ops(class("Template"), templatemt)
function Template:__init(packname, data)
	libs.check.string(packname)
	libs.check.table(data)

	self._logger  = dct.libs.Logger.getByName("Template")
	self._valid   = false
	self.data     = data

	self._valid = self:validate()

	self.name     = string.lower(data.name)
	self.packname = string.lower(packname)
	self.objtype  = data.objtype

	-- remove static functions
	self.fromZone = nil
	self.fromGroup = nil
	self.fromDCSGroup = nil
end

function Template.fromZone(packname, zone)
	local tpl = Template(packname, zone)
	return tpl
end

function Template.fromGroup(packname --[[, grp]])
	-- TODO: write conversion of grp to a data table
	-- local grpdata = grptbl_to_data(grp)
	local tpl = Template(packname --[[, grpdata]])
	return tpl
end

function Template.fromDCSGroup(grp)
	local name = grp:getName()
	local owner = grp:getCoalition()
	local objtype = group_category_map[grp:getCategory()]
	local tpldata = tpldata_from_dcsgroup(grp)

	local data = {}
	data.name      = name
	data.coalition = utils.getkey(coalition.side, owner)
	data.tpldata   = tpldata
	data.objtype   = objtype
	data.overwrite = false
	data.rename    = false
	-- TODO: check if this group is a player slot

	local tpl = Template("dcs", data)
	return tpl
end

--- Validates user `data` according to the checkers defined in `checkers`.
--
-- @param data data to validate
-- @return bool, true on successful validation with no errors; false otherwise
function Template:validate()
	local copyoptions = {}

	if checkers == nil then
		checkers = set_checkers()
	end

	for _, checker in ipairs(checkers) do
		local ok, key, msg = checker:check(self.data)

		if not ok then
			self._logger:error("%s: invalid `%s` %s",
				tostring(self), tostring(key), tostring(msg))
			return ok
		end

		utils.mergetables(copyoptions, checker:agentOptions())
	end
	self.agentDescKeys = copyoptions
	return true
end

--- Is the Template valid, a Template can fail validation without killing
-- the game. It is up to the user of the Template to make sure the Template
-- is valid.
function Template:isValid()
	return self._valid
end

function Template:getName()
	return tostring(self)
end

--- Generate an asset name.
-- An asset must have a unique name or it will not be added to the
-- AssetManager. This function guarantees compliance with this requirement.
-- @return a predictable unique name
function Template:genName()
	local name = self.data.name

	if self.data.rename then
		name = self.packname.."."..self.name.."_"..self.data.coalition
		if self.data.uniquenames == true then
			name = name.." #"..dct.Theater.singleton():getcntr()
		end
	end
	return name
end

--- Associate this Template with the given agent.
function Template:attach(agent)
	agent.desc = self:genDesc()
	agent:setDescKey("template", tostring(self))
end

--- Create a DCT game object from the template definition.
--
-- @return the object created
function Template:getAgentArgs()
	return self:genName(), self.data.coalition, self.objtype
end

--- Generate the description table from the Template. Is usually given
-- to the asset to store locally.
function Template:genDesc()
	local desc = {}
	for k, _ in pairs(self.agentDescKeys) do
		desc[k] = utils.deepcopy(self.data[k])
	end

	if self.data.uniquenames == true then
		desc.codename = genCodename(self)
		desc.locationmethod = genLocationMethod()
		makeNamesUnique(desc.tpldata)
	end
	return desc
end

return Template
