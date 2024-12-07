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
	System.__init(self, theater, System.SYSTEMORDER.TEMPLATEDB)
	self._db = {}
end

--- Load all common and theater specific templates.
function TemplateDB:initialize()
	local commonTplPath = utils.join_paths(dct.modpath, "templates")
	local theaterTplPath = utils.join_paths(self._theater:getPath(),
						"templates")
	local common_packs = make_hashtbl(TemplateDB.settings.load_packages)

	if next(common_packs) then
		for filename in dir_filtered(commonTplPath, no_dirs) do
			local msnpath = utils.join_paths(commonTplPath,
							 filename)
			local miz, err = MIZ.loadfile(msnpath)

			if miz == nil then
				self._logger:error("%s", err)
			elseif common_packs[string.lower(miz.sortie)] then
				self:loadPack(miz)
			end
		end
	end

	for filename in dir_filtered(theaterTplPath, no_dirs) do
		local msnpath = utils.join_paths(theaterTplPath, filename)
		local miz, err = MIZ.loadfile(msnpath)

		if miz ~= nil then
			self:loadPack(miz)
		else
			self._logger:error("%s", err)
		end
	end
end

--- Add a template to the database.
-- @tparam Template tpl the Template object to add.
function TemplateDB:add(tpl)
	if not tpl:isValid() then
		return
	end
	self._db[tpl.name] = tpl
end

--- Load a template pack.
-- Associates a trigger zone with unit/static groups by the
-- name of the group which follows the format; `<zone name>:<group name>`.
-- @param packtbl the lua mission table we should process to create
--     templates.
function TemplateDB:loadPack(miz)
	local packname = miz.sortie
	local templates = {}

	-- TODO: do not load packs that require modules not loaded in
	-- the current mission; env.mission.requiredModules
	-- Not sure how to accomplish this.

	for _, zone in pairs(miz.zones) do
		local t = Template.fromZone(packname, zone)

		if t ~= nil then
			templates[t.name] = t
		end
	end

	for name, grp in pairs(miz.groups) do
		local tplname = splitname(name, ":")[1] or ""
		local t = templates[tplname]

		if t ~= nil then
			t:addGroup(grp)
		end
	end

	for _, t in pairs(templates) do
		if t:validate() then
			self:add(t)
		end
	end
end

function TemplateDB:find(desc)
	-- TODO: write me.
	-- Find templates matching a description.
	-- return a list of templates matching the provided description.
end

return TemplateDB
