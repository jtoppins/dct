-- SPDX-License-Identifier: LGPL-3.0

require("math")
require("libs")
local class     = libs.classnamed
local check     = libs.check
local dctutils  = require("dct.libs.utils")
local uirequest = require("dct.ui.request")
local WS        = require("dct.assets.worldstate")

local function _request(data)
	local theater = dct.Theater.singleton()

	if data == nil then
		theater._logger:debug("nil data, ignoring")
		return
	end

	local player = theater:getAssetMgr():getAsset(data.name)

	if player == nil then
		theater._logger:debug("no player by name: %s", data.name)
		return
	end

	if player:getFact(WS.Facts.factKey.CMDPENDING) ~= nil then
		player._logger:debug("request pending, ignoring")
		uirequest.post_msg(player, WS.Facts.factKey.CMDMSG,
			"Request already pending, please wait.", 20)
		return
	end

	uirequest.defer_request(player, data)
end

local function do_request(data)
	local ok, err = pcall(_request, data)

	if not ok then
		dctutils.errhandler(err, dct.Logger.getByName("UI"))
	end
end


local PlayerCmd = class("PlayerCmd")
function PlayerCmd:__init(title, handler, data, parent, player)
	local ppath = nil
	if parent ~= nil then
		ppath = parent.path
		self.gid = parent.gid
		self.name = parent.name
	elseif player ~= nil then
		self.gid = player:getDescKey("groupId")
		self.name = player.name
	end

	self.title = title
	self.parent = parent
	self.path = missionCommands.addCommandForGroup(self.gid, title, ppath,
						       handler, data)
end

function PlayerCmd.create(title, callback, val, args, parent, player)
	check.func(callback)
	if args == nil then
		args = {}
	end

	if parent ~= nil then
		args.name = parent.name
	elseif player ~= nil then
		args.name = player.name
	end
	args.callback = callback
	args.value = val

	return PlayerCmd(title, do_request, args, parent, player)
end

function PlayerCmd:destroy()
	missionCommands.removeItemForGroup(self.gid, self.path)
end


local PlayerMenu = class("PlayerMenu")
function PlayerMenu:__init(title, parent, player, create)
	local ppath = nil
	if parent ~= nil then
		ppath = parent.path
		self.gid = parent.gid
		self.name = parent.name
	elseif player ~= nil then
		self.gid = player:getDescKey("groupId")
		self.name = player.name
	end

	self.title = title
	self.parent = parent
	self.path = missionCommands.addSubMenuForGroup(self.gid, title, ppath)
	self.player = player
	self.create_cb = create
	self.children = {}

	-- create the initial menu
	if self.create_cb ~= nil then
		self.create_cb(self, player)
	end
end

--- Clear the menu of all entries but do not destroy the root menu item.
-- Reverse loop over all menu entries removing children first.
function PlayerMenu:clear()
	for i = #self.children, 1, -1 do
		self.children[i]:destroy()
		table.remove(self.children, i)
	end
end

--- Reset the menu using the original initialization function the
-- menu was created with.
function PlayerMenu:reset()
	self:clear()
	self.create_cb(self, self.player)
end

function PlayerMenu:destroy()
	self:clear()
	self.children = {}
	missionCommands.removeItemForGroup(self.gid, self.path)
end

--- Remove a specific menu entry.
--
-- @param entry the entry we want to delete
function PlayerMenu:remove(entry)
	for i = #self.children, 1, -1 do
		if self.children[i] == entry then
			table.remove(self.children, i)
			break
		end
	end
end

function PlayerMenu:children()
	return self.children
end

function PlayerMenu:setCreateCB(callback)
	self.create_cb = callback
end

function PlayerMenu:getCreateCB()
	return self.create_cb
end

function PlayerMenu:addMenu(title)
	local menu = PlayerMenu(title, self)
	table.insert(self.children, menu)
	return menu
end

function PlayerMenu:addCmd(title, handler, data)
	local cmd = PlayerCmd(title, handler, data, self)
	table.insert(self.children, cmd)
	return cmd
end

function PlayerMenu:addRqstCmd(title, callback, val, args)
	local cmd = PlayerCmd.create(title, callback, val, args, self)
	table.insert(self.children, cmd)
	return cmd
end

local _pm = {}
_pm.Menu = PlayerMenu
_pm.Cmd  = PlayerCmd

return _pm
