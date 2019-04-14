--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--]]

require("os")

do
	local class    = require("libs.class")
	local utils    = require("libs.utils")
	--local settings = require("dct.settings")

	local categorymap = {
		["HELICOPTER"] = 'HELICOPTER',
		["SHIP"]       = 'SHIP',
		["VEHICLE"]    = 'GROUND_UNIT',
		["PLANE"]      = 'AIRPLANE',
		["STATIC"]     = 'STRUCTURE',
	}

	local function lookupname(name, namelist)
		namelist = namelist or {}
		if namelist[name] ~= nil then
			name = namelist[name]
		end
		return name
	end
	local function overrideGroupOptions(grp, ctx)
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
		grp.name    = lookupname(grp.name, ctx.names)
		grp.groupId = nil

	end
	local function overrideUnitOptions(key, unit, ctx)
		if unit.playerCanDriver ~= nil then
			unit.playerCanDrive = false
		end
		unit.unitId = nil
		unit.name = lookupname(unit.name, ctx.names)
	end
	local function overrideName(key, obj, ctx)
		obj.name = lookupname(obj.name, ctx.names)
	end
	local function spawnGroup(id, group, category)
		assert(id)
		assert(group)
		assert(category)
		coalition.addGroup(group.countryid,
				   Unit.Category[categorymap[string.upper(category)]],
				   group.data)
	end
	local function spawnStatic(id, static)
		assert(id)
		assert(static)
		coalition.addStaticObject(static.countryid, static.data)
	end


	--[[
	--  Template class
	--    base class that reads in a template file and organizes
	--    the data for spawning.
	--
	--  Storage of templates:
	--  side = {
	--      category = {
	--          # = {
	--              countryid = id,
	--              grpdata   = data
	--          }
	--      }
	--  }
	--]]
	local Template = class()
	function Template:__init(stmfile, dctfile)
		local rc  = false

		rc = pcall(dofile, stmfile)
		assert(rc, "failed to parse: " .. stmfile)
		rc = pcall(dofile, dctfile)
		assert(rc, "failed to parse: " .. dctfile)

		assert(staticTemplate ~= nil)
		assert(metadata ~= nil)

		local tpl = staticTemplate
		tpl.metadata = metadata
		staticTemplate = nil
		metadata = nil

		self.name    = lookupname(tpl.name, tpl.localization.DEFAULT)
		self.theatre = tpl.theatre
		self.desc    = tpl.desc
		self.tpldata = {}

		for coa_key, coa_data in pairs(tpl.coalition) do
			self:__processCoalition(coa_key, coa_data,
						tpl.localization.DEFAULT)
		end
		for key, data in pairs(tpl.metadata) do
			self[key] = data
		end
	end
	function Template:__processCoalition(side, coa, names)
		if side ~= 'red' and side ~= 'blue' and
		   type(coa) ~= 'table' then
			return
		end

		if coa.country == nil or type(coa.country) ~= 'table' then
			return
		end

		for ctry_key, ctry_data in ipairs(coa.country) do
			self:__processCountry(side, ctry_data, names)
		end
	end
	function Template:__processCountry(side, ctry, names)
		local ctx = {}
		ctx.side      = side
		ctx.category  = "none"
		ctx.countryid = ctry.id
		ctx.names     = names

		for cat, _ in pairs(categorymap) do
			cat = string.lower(cat)
			if ctry[cat] and type(ctry[cat]) == 'table' and
			   ctry[cat].group then
				ctx.category = cat
				self:__processGroups(ctry[cat].group,
						     self.__addOneGroup,
						     ctx)
			end
		end


		if ctry.static and type(ctry.static) == 'table' and
		   ctry.static.group then
			ctx.category = "static"
			self:__processGroups(ctry.static.group,
					     self.__addOneStatic,
					     ctx)
		end
	end
	function Template:__processGroups(list, fcn, ctx)
		for idx, data in ipairs(list) do
			fcn(self, ctx, data)
		end
	end
	function Template:__addOneStatic(ctx, grp)
		local tbl = {}

		self:__createTable(ctx)

		tbl.data        = grp.units[1]
		tbl.data.dead   = grp.dead
		tbl.data.name   = self.name .. " static " ..
				  #self.tpldata[ctx.side][ctx.category]
		-- delete unneeded fields
		tbl.data.unitId = nil
		tbl.countryid = ctx.countryid

		-- TODO: setup metadata like parsing group/unit names
		-- to determine how a much of the group needs to be
		-- destroyed or if specific units need to be
		-- damaged/destroyed.
		-- 	Notes:
		-- 	if deadstate is a number, it represents
		-- 	the overall group's health state as defined
		-- 	by the arithmetic mean
		--
		-- 	if deadstate is a table, it represents
		-- 	a map keyed on unit position in the group
		-- 	and the unit's state. The absence of a unit's
		-- 	position key means it doesn't matter what that
		-- 	unit's state is.
		-- tbl.deadstate =

		table.insert(self.tpldata[ctx.side][ctx.category], tbl)
	end
	function Template:__addOneGroup(ctx, grp)
		local tbl = {}

		self:__createTable(ctx)

		tbl.data = grp
		overrideGroupOptions(tbl.data, ctx)
		utils.foreach(tbl.data.units,
			      ipairs,
			      overrideUnitOptions,
			      ctx)
		utils.foreach(tbl.data.route.points,
			      ipairs,
			      overrideName,
			      ctx)
		tbl.countryid = ctx.countryid
		-- TODO: setup metadata like parsing group/unit names


		-- now override group/unit names to be unique to the
		-- template
		tbl.data.name = self.name .. " " .. ctx.category .. " " ..
				#self.tpldata[ctx.side][ctx.category]
		utils.foreach(tbl.data.units,
			ipairs,
			function(i, obj, base)
				obj.name = base .. "-" .. i
			end,
			tbl.data.name)
		table.insert(self.tpldata[ctx.side][ctx.category], tbl)
	end
	function Template:__createTable(ctx)
		local data = self.tpldata
		if data[ctx.side] then
			if data[ctx.side][ctx.category] == nil then
				data[ctx.side][ctx.category] = {}
			end
		else
			data[ctx.side] = {}
			data[ctx.side][ctx.category] = {}
		end
	end

	function Template:spawn()
		for coa_key, coa_data in pairs(self.tpldata) do
			for cat_idx, cat_data in pairs(coa_data) do
				if cat_idx == 'static' then
					utils.foreach(cat_data,
						      ipairs,
						      spawnStatic,
						      nil)
				else
					utils.foreach(cat_data,
						      ipairs,
						      spawnGroup,
						      cat_idx)
				end
			end
		end
	end

	return {
		["Template"] = Template,
	}
end
