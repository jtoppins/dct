--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions for handling templates.
--   Template template_read(filepath)
--
<template-root>
	generic
		<category:facility|ground|air|ship>
			<name>.stm
		facility
			<name>.stm
	<mission-name>
		<category:facility|ground|air|ship>
			<name>.{stm|dct}
		facility
			<name>.{stm|dct}

Template Categories:
* facility
	- assets that generally do not move; play a role in the overall
	  strategic success in the theater and change the flow of the
	  situation slowly.

types (taken from the NATO Joint Military Symbology list):
	base
	ewr
	artillery
	missile
	sam
	ammo dump
	fuel dump
	depots
	c2
	gcv (ground convoy vehicle)
	factory
	bai
--]]

require("os")

do
	local debug = os.getenv("DCT_DEBUG")
	local utils = {}
	function utils.foreach(array, itr, fcn, ctx)
		for k, v in itr(array) do
			fcn(k, v, ctx)
		end
	end

	function utils.debug(str)
		if debug == nil then
			return
		end
		print("DEBUG: "..str)
	end

	local class    = require("libs.class")
	--local utils    = require("libs.utils")
	--local settings = require("dct.settings")

	local function lookupname(name, namelist)
		namelist = namelist or {}
		if namelist[name] ~= nil then
			name = namelist[name]
		end
		return name
	end
	local function overrideGroupOptions(grp)
		local opts = {
			visible        = true,
			uncontrollable = true,
			uncontrolled   = true,
			hidden         = true,
			lateActivation = false,
		}

		for k, v in pairs(opts) do
			if grp[k] ~= nil then grp[k] = v end
		end
		grp.groupId = nil
	end
	local function overrideUnitOptions(key, unit, ctx)
		if unit.playerCanDriver ~= nil then
			unit.playerCanDrive = false
		end
		unit.unitId = nil
	end
	local function overrideName(key, obj, ctx)
		obj.name = lookupname(obj.name, ctx.names)
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
	function Template:__init(stmfile, dtcfile)
		local rc  = false

		rc = pcall(dofile, stmfile)
		assert(rc, "failed to parse: " .. stmfile)
		utils.debug("here0")
		--rc = pcall(dofile, dctfile)
		utils.debug("here1")
		--assert(rc, "failed to parse: " .. dctfile)
		utils.debug("here1-1")

		assert(staticTemplate ~= nil)
		--assert(metadata ~= nil)

		local tpl = staticTemplate
		--tpl.metadata = metadata
		staticTemplate = nil
		--metadata = nil

		utils.debug("here2")

		self.name    = lookupname(tpl.name, tpl.localization.DEFAULT)
		self.theatre = tpl.theatre
		self.desc    = tpl.desc
		self.tpldata = {}

		for coa_key, coa_data in pairs(tpl.coalition) do
			self:__processCoalition(coa_key, coa_data,
						tpl.localization.DEFAULT)
		end
		--for key, data in pairs(tpl.dct) do
		--	self[key] = data
		--end
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
		local categories = {"ship", "vehicle", "air"}
		local ctx = {}
		ctx.side      = side
		ctx.category  = "none"
		ctx.countryid = ctry.id
		ctx.names     = names
		--ctx.tpl       = self

		for i, cat in ipairs(categories) do
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
	-- TODO: vv - this function could eventually be removed with a
	-- generic like utils.foreach()
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
		overrideGroupOptions(tbl.data)
		utils.foreach(tbl.data.units,
			      ipairs,
			      overrideUnitOptions,
			      ctx)
		utils.foreach(tbl.data.route.points,
			      ipairs,
			      overrideName,
			      ctx)
		-- TODO: setup metadata like parsing group/unit names
		tbl.countryid = ctx.countryid
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
		local ctx = {}

		for coa_key, coa_data in pairs(self.tpldata) do
			for cat_idx, cat_data in ipairs(coa_data) do
				if cat_idx == 'static' then
					utils.foreach(cat_data,
						      self.__spawnStatic,
						      ipairs,
						      cat_idx)
				else
					utils.foreach(self.tpldata,
						      self.__spawnGroup,
						      ipairs,
						      cat_idx)
				end
			end
		end
	end
	function Template:__spawnGroup(id, group, category)
		utils.debug("spawnGroup")
		coalition.addGroup(group.countryid, category, group.data)
	end
	function Template:__spawnStatic(id, static, unused)
		utils.debug("spawnStatic")
		coalition.addStaticObject(static.countryid, static.data)
	end

	return {
		["Template"] = Template,
	}
end
