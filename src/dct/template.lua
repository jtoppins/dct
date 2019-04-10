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
	local class    = require("dcs-mission-libs.class")
	local utils    = require("dcs-mission-libs.utils")
	local settings = require("dct.settings")
	local mission  = require("dct.mission")

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
	function Template:__init(category, name)
		dofile(settings.tmpldir() .. category .. name .. ".stm")
		dofile(settings.tmpldir() .. category .. name .. ".dct")

		local tpl = staticTemplate
		tpl.dct = dct
		staticTemplate = nil
		dct = nil

		self.name = mission.lookupname(tpl.name,
					       tpl.localization.DEFAULT)
		self.theatre = tpl.theatre
		self.desc = tpl.desc

		for coa_key, coa_data in pairs(tpl.coalition) do
			self:__processCoalition(coa_key, coa_data)
		end
		for key, data in pairs(tpl.dct) do
			self[key] = data
		end
	end
	function Template:__processCoalition(side, coa)
		if side ~= 'red' and side ~= 'blue' and
		   type(coa) ~= 'table' then
			return
		end

		if coa.country == nil or type(coa.country) ~= 'table' then
			return
		end

		for ctry_key, ctry_data in ipairs(coa.country) do
			self:__processCountry(side, ctry_data)
		end
	end
	function Template:__processCountry(side, ctry)
		local categories = {"ship", "vehicle", "air"}
		local ctx = {}
		ctx.side      = side
		ctx.category  = "none"
		ctx.countryid = ctry.id

		for i, cat in iparis(categories) do
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

		tbl.data        = utils.copy(grp.units[1])
		tbl.data.dead   = grp.dead
		tbl.data.name   = self.name .. " static " ..
				  #self[ctx.side][ctx.category]

		tbl.countryid = ctx.countryid
		-- delete unneeded fields
		tbl.data.unitId = nil

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

		table.insert(self[ctx.side][ctx.category], tbl)
	end
	function Template:__addOneGroup(ctx, grp)
		
	end

	function Template:__createTable(ctx)
		if self[ctx.side] then
			if self[ctx.side][ctx.category] == nil then
				self[ctx.side][ctx.category] = {}
			end
		else
			self[ctx.side] = {}
			self[ctx.side][ctx.category] = {}
		end
	end

	function Template:spawn()
	end
	function Template:spawnLocation(pos, rotation)
	end
	function Template:__spawnGroups()
	end
	function Template:__spawnStatics()
	end
end
