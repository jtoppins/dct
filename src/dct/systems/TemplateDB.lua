-- SPDX-License-Identifier: LGPL-3.0

--- Template database.
-- @classmod dct.systems.TemplateDB

local mylfs = require("lfs")
require("libs")
local class    = libs.classnamed
local utils    = libs.utils
local System   = require("dct.libs.System")
local MIZ      = require("dct.templates.MIZ")
local Template = require("dct.templates.Template")

local zonetypes = {
	["CIRCLE"] = 0,
	["POLY"]   = 2,
}

local function make_hashtbl(lst, transform)
	transform = transform or string.lower
	local hashtbl = {}

	for _, value in ipairs(lst) do
		hashtbl[transform(value)] = true
	end

	return hashtbl
end

local function dir_filtered(path, filter)
	local iter, dir_obj = mylfs.dir(path)
	local function fnext(state)
		local filename

		repeat
			filename = iter(state)
			if filename == nil then
				return nil
			end
		until(filter(path, filename))
		return filename
	end
	return fnext, dir_obj, iter
end

local function no_dirs(base, filename)
	local fattr = mylfs.attributes(utils.join_paths(base, filename))
	return fattr.mode ~= "directory"
end

--- Template database.
-- Implements a datastore for all templates that are planned to be used
-- in the campaign.
local TemplateDB = class("TemplateDB", System)

TemplateDB.enabled = true
TemplateDB.settings = {}

--- List of template packs that should be loaded from the common
-- set of packs.
TemplateDB.settings.load_packages = {}

--- Constructor.
function TemplateDB:__init(theater)
	System.__init(self, theater, System.SYSTEMORDER.TEMPLATEDB,
		      System.SYSTEMALIAS.TEMPLATEDB)
	self._db = {}
end

--- Load all common and theater specific templates.
function TemplateDB:initialize()
	local commonTplPath = dct.templatepath
	local theaterTplPath = utils.join_paths(self._theater:getPath(),
						"templates")
	local common_packs = make_hashtbl(TemplateDB.settings.load_packages)

	if next(common_packs) and utils.isDir(commonTplPath) then
		for filename in dir_filtered(commonTplPath, no_dirs) do
			local msnpath = utils.join_paths(commonTplPath,
							 filename)
			self._logger:debug("attempting to load template pack: %s",
					  msnpath)
			local miz, err = MIZ.loadfile(msnpath)

			if miz == nil then
				self._logger:error("%s", err)
			elseif common_packs[string.lower(miz.sortie)] then
				self:loadPack(miz)
			end
		end
	end

	if utils.isDir(theaterTplPath) then
		for filename in dir_filtered(theaterTplPath, no_dirs) do
			local msnpath = utils.join_paths(theaterTplPath,
							 filename)
			self._logger:debug("attempting to load template pack: %s",
					  msnpath)
			local miz, err = MIZ.loadfile(msnpath)

			if miz == nil then
				self._logger:error("%s", err)
			else
				self:loadPack(miz)
			end
		end
	end
	return true
end

--- Add a template to the database.
-- @tparam Template tpl the Template object to add.
function TemplateDB:add(tpl)
	if not tpl:isValid() then
		return
	end
	local tplname = tostring(tpl)
	self._db[tplname] = tpl
	self._logger:debug("  adding template: %s", tplname)
end

--- Load a template pack.
-- Associates a trigger zone with unit/static groups by the
-- name of the group which follows the format; `<zone name>:<group name>`.
-- @param miz the lua mission table we should process to create
--     templates.
function TemplateDB:loadPack(miz)
	local packname = miz.sortie
	local templates = {}
	local props = miz.zones["properties"]
	miz.zones["properties"] = nil

	-- TODO: use heading in zones to indicate the direction of the front of
	--       the template. This way when a relocatable object is rotated
	--       it will be relative to where it is facing in the original
	--       template.

	-- TODO: do not load packs that require modules not loaded in
	--       the current mission; env.mission.requiredModules
	--       Not sure how to accomplish this.

	-- TODO: look for a configuration attribute in the specially named
	--       zone that will signal if the packs valid template names
	--       and attributes should be dumped. This will allow the
	--       designer easier ability to figure out what they should
	--       be referencing in campaign mission. Store the dump
	--       in a json file named after the package name in a location
	--       specified in the server settings.

	for idx, zone in pairs(miz.zones) do
		if zone.type == zonetypes.CIRCLE then
			templates[zone.name] = {
				["handler"] = "fromZone",
				["obj"] = zone,
			}
			miz.zones[idx] = nil
		elseif zone.type == zonetypes.POLY then
			print("TODO - convert zones pointing to scenery")
			-- TODO: convert zones pointing to scenery objects to
			-- groups and append the groups table
		end
	end

	for name, grp in pairs(miz.groups) do
		local tplname = utils.split(name, ":")[1] or ""
		local t = templates[tplname]

		if t ~= nil then
			table.insert(t.obj.groups, grp)
		else
			templates[grp.name] = {
				["handler"] = "fromGroup",
				["obj"] = grp,
			}
		end
	end

	for _, t in pairs(templates) do
		self._logger:debug("possible template: %s", t.obj.name)
		local tpl = Template[t.handler](packname, t.obj, props)
		if tpl ~= nil then
			self:add(tpl)
		end
	end
end

function TemplateDB:find(--[[desc]])
	-- TODO: write me.
	-- Find templates matching a description.
	-- return a list of templates matching the provided description.
end

return TemplateDB
