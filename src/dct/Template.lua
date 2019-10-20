--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

require("lfs")
local class    = require("libs.class")
local utils    = require("libs.utils")
local dctenums = require("dct.enum")
local Goal     = require("dct.Goal")

local categorymap = {
	["HELICOPTER"] = 'HELICOPTER',
	["SHIP"]       = 'SHIP',
	["VEHICLE"]    = 'GROUND_UNIT',
	["PLANE"]      = 'AIRPLANE',
	["STATIC"]     = 'STRUCTURE',
}

local function checktype(val)
	local allowed = dctenums.assetType
	if allowed[string.upper(val)] then
		return true
	end
	return false
end

local function settype(tbl, key)
	local allowed = dctenums.assetType
	tbl[key] = allowed[string.upper(tbl[key])]
end

--[[
-- represents the amount of damage that can be taken before
-- that state is no longer consitered valid.
-- example:
--   goal: damage unit to 85% of original health (aka incapacitate)
--
--   unit.health = .85
--   goal = 85
--   damage_taken = (1 - unit.health) * 100 = 15
--
--   if damage_taken > goal = goal met, in this case we have
--   not met our greater than 85% damage.
--]]
local damage = {
	["UNDAMAGED"]     = 10,
	["DAMAGED"]       = 45,
	["INCAPACITATED"] = 75,
	["DESTROYED"]     = 90,
}

--[[
-- generates a death goal from an object's name by
-- using keywords.
--]]
local function goalFromName(name, objtype)
	local goal = {}
	local goalvalid = false
	name = string.upper(name)

	for k, v in pairs(Goal.priority) do
		local index = string.find(name, k)
		if index ~= nil then
			goal.priority = v
			goalvalid = true
			break
		end
	end

	for k, v in pairs(damage) do
		local index = string.find(name, k)
		if index ~= nil then
			goal.value = v
			goalvalid = true
			break
		end
	end

	if not goalvalid then
		return nil
	end
	if goal.priority == nil then
		goal.priority = Goal.priority.PRIMARY
	end
	if goal.value == nil then
		goal.value = damage.INCAPACITATED
	end
	goal.objtype  = objtype
	goal.goaltype = Goal.goaltype.DAMAGE
	return goal
end

-- unique name counter, allows us to generate names that are always unique
-- TODO: this value would need to be saved for mission persistance
local namecntr = 1000

local function getcntr()
	namecntr = namecntr + 1
	return namecntr
end

local function makeNamesUnique(data)
	for _, cat_data in pairs(data) do
		for _, grp in ipairs(cat_data) do
			grp.data.name = grp.data.name .. " #" .. getcntr()
			for _, v in ipairs(grp.units or {}) do
				v.name = v.name .. " #" .. getcntr()
			end
		end
	end
end

--[[
--  Template class
--    base class that reads in a template file and organizes
--    the data for spawning.
--
--    properties
--    ----------
--      * objtype   - represents an abstract type of asset
--      * name      - name of the template
--      * region    - the region name the template belongs too
--      * coalition - which coalition the template belongs too
--                    templates can only belong to one side and
--                    one side only
--      * desc      - description of the template, used to generate
--		              mission breifings from
--
--    Storage
--    -------
--    tpldata = {
--      category = {
--        # = {
--          countryid = id,
--          grpdata   = {
--            # group def members
--            dct_deathgoal = goalspec
--          }
--        }
--      }
--    }
--
--    DCT File
--    --------
--      Required Keys:
--        * objtype - the kind of "game object" the template represents
--
--      Optional Keys:
--        * uniquenames - when a Template's data is copied the group and
--              unit names a guaranteed to be unique if true
--        * priority - the relative importance of the template in relation
--              to other templates
--        * rank - determines if the template is a "primary", "secondary"
--              or "tertiary" target.
--        * base - [Required] only used if the 'objtype' represents some
--              sort of base object that needs to be associated with a
--              DCS base object, the name of the DCS base is put here.
--
--]]
local Template = class()
function Template:__init(regionname, stmfile, dctfile)
	assert(regionname ~= nil, "regionname is required")
	assert(stmfile ~= nil,    "stmfile is required")
	assert(dctfile ~= nil,    "dctfile is required")
	self.regionname = regionname
	self.path = stmfile
	self.hasDeathGoals = false
	self:__loadMetadata(dctfile)
	self:__loadSTM(stmfile)

	-- remove unneeded functions
	self.__lookupname = nil
	self.categorymap  = nil
end

function Template:__lookupname(name)
	local newname = name
	local namelist = self.tplnames or {}
	if namelist[name] ~= nil then
		newname = namelist[name]
	end
	return newname
end

function Template:__loadMetadata(dctfile)
	local requiredkeys = {
		["objtype"]  = {
			["type"]  = "string",
			["check"] = checktype,
			["set"]   = settype,
		},
	}

	assert(lfs.attributes(dctfile) ~= nil, "file does not exist: "..dctfile)
	local rc = pcall(dofile, dctfile)
	assert(rc, "failed to parse: "..dctfile)
	assert(metadata ~= nil)

	-- validate metadata
	for key, data in pairs(requiredkeys) do
		if metadata[key] == nil or
		   type(metadata[key]) ~= data["type"] or
		   not data["check"](metadata[key]) then
			assert(false, "invalid or missing option '"..key..
			       "' in dct file; "..dctfile)
		else
			if data["set"] ~= nil and type(data["set"]) == "function" then
				data["set"](metadata, key)
			end
		end
	end
	utils.mergetables(self, metadata)
	metadata = nil

	local optionalkeys = {
		["uniquenames"] = {
			["type"]    = "boolean",
			["default"] = false,
		},
		["priority"] = {
			["type"]    = "number",
			["default"] = 1,
		},
		["rank"] = {
			["type"]    = "number",
			["default"] = Goal.priority.SECONDARY,
		},
	}

	for key, data in pairs(optionalkeys) do
		if self[key] == nil or
		   type(self[key]) ~= data["type"] then
		   self[key] = data["default"]
		end
	end
end

function Template:__loadSTM(stmfile)
	assert(lfs.attributes(stmfile) ~= nil, "file does not exist: "..stmfile)
	local rc = pcall(dofile, stmfile)
	assert(rc, "failed to parse: "..stmfile)
	assert(staticTemplate ~= nil)

	local tpl = staticTemplate
	staticTemplate = nil

	self.tplnames= tpl.localization.DEFAULT
	self.name    = self:__lookupname(tpl.name)
	self.theatre = tpl.theatre
	self.desc    = tpl.desc
	self.tpldata = {}

	for coa_key, coa_data in pairs(tpl.coalition) do
		self:__processCoalition(coa_key, coa_data)
	end
	self.tplnames= nil
end

function Template:__processCoalition(side, coa)
	if side ~= 'red' and side ~= 'blue' and
	   type(coa) ~= 'table' then
		return
	end

	if coa.country == nil or type(coa.country) ~= 'table' then
		return
	end

	for _, ctry_data in ipairs(coa.country) do
		side = coalition.getCountryCoalition(ctry_data.id)
		self:__processCountry(side, ctry_data)
	end
end

function Template:__processCountry(side, ctry)
	local funcmap = {
		["HELICOPTER"] = self.__addOneGroup,
		["SHIP"]       = self.__addOneGroup,
		["VEHICLE"]    = self.__addOneGroup,
		["PLANE"]      = self.__addOneGroup,
		["STATIC"]     = self.__addOneStatic,
	}

	local ctx = {}
	ctx.side      = side
	ctx.category  = "none"
	ctx.countryid = ctry.id

	for cat, _ in pairs(categorymap) do
		cat = string.lower(cat)
		if ctry[cat] and type(ctry[cat]) == 'table' and
		   ctry[cat].group then
			if self.coalition == nil then
				self.coalition = side
			end
			assert(self.coalition == side, "country("..ctry.id..") does not"..
				" belong to template.coalition("..self.coalition.."),"..
				" country belongs to "..side.." in file: "..self.path)

			ctx.category = cat
			utils.foreach(self,
					ipairs,
					funcmap[string.upper(cat)],
					ctry[cat].group,
					ctx)
		end
	end
end

function Template:__overrideUnitOptions(key, unit, ctx)
	if unit.playerCanDriver ~= nil then
		unit.playerCanDrive = false
	end
	unit.unitId = nil
	unit.dct_deathgoal = goalFromName(self:__lookupname(unit.name),
	                                  Goal.objtype.UNIT)
	if unit.dct_deathgoal ~= nil then
		self.hasDeathGoals = true
	end
	unit.name = ctx.basename.."-"..key
end

function Template:__overrideGroupOptions(grp, ctx)
	local opts = {
		visible        = true,
		uncontrollable = true,
		uncontrolled   = true,
		hidden         = false,
		lateActivation = false,
	}

	for k, v in pairs(opts) do
		if grp[k] ~= nil then grp[k] = v end
	end
	grp.groupId = nil
	grp.start_time = 0
	grp.dct_deathgoal = goalFromName(self:__lookupname(grp.name),
	                                 Goal.objtype.GROUP)
	if grp.dct_deathgoal ~= nil then
		self.hasDeathGoals = true
	end
	grp.name = self.regionname.."_"..self.name.." "..ctx.side.." "..
			ctx.category.." "..#self.tpldata[ctx.category]
	ctx.basename = grp.name
	utils.foreach(self,
		ipairs,
		self.__overrideUnitOptions,
		grp.units or {},
		ctx)
	-- lookup waypoint names
	utils.foreach(ctx,
		ipairs,
		function(_, _, obj)
			obj.name = self:__lookupname(obj.name)
		end,
		grp.route.points or {})
end

function Template:__addOneStatic(_, grp, ctx)
	local tbl = {}

	self:__createTable(ctx)

	self:__overrideGroupOptions(grp, ctx)
	tbl.data      = grp.units[1]
	if tbl.data.dct_deathgoal ~= nil then
		tbl.data.dct_deathgoal.objtype = Goal.objtype.STATIC
	end
	tbl.data.dead = grp.dead
	tbl.countryid = ctx.countryid

	table.insert(self.tpldata[ctx.category], tbl)
end

function Template:__addOneGroup(_, grp, ctx)
	local tbl = {}

	self:__createTable(ctx)

	self:__overrideGroupOptions(grp, ctx)
	tbl.data = grp
	tbl.countryid = ctx.countryid

	table.insert(self.tpldata[ctx.category], tbl)
end

function Template:__createTable(ctx)
	local data = self.tpldata
	if data[ctx.category] == nil then
		data[ctx.category] = {}
	end
end

-- PUBLIC INTERFACE
function Template:copyData()
	local copy = utils.deepcopy(self.tpldata)
	if self.uniquenames ~= true then
		makeNamesUnique(copy)
	end
	return copy
end

Template.categorymap = categorymap

return Template
