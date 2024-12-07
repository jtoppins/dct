-- SPDX-License-Identifier: LGPL-3.0

require("math")
require("libs")
local class     = libs.classnamed
local check     = libs.check
local dctutils  = require("dct.libs.utils")
local uirequest = require("dct.ui.request")
local WS        = require("dct.agent.worldstate")
local removeGroupItem = missionCommands.removeItemForGroup
local addGroupMenu    = missionCommands.addSubMenuForGroup
local addGroupCmd     = missionCommands.addCommandForGroup

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
		dctutils.errhandler(err, dct.libs.Logger.getByName("UI"))
	end
end

local MenuItem = class("MenuItem")
function MenuItem:__init(title)
	self.title = title
end

function MenuItem:clone()
	return libs.utils.deepcopy(self)
end

function MenuItem:draw(--[[gid, parent, player]])
	assert(false, "must be overridden")
end

local PlayerCmd = class("PlayerCmd", MenuItem)
function PlayerCmd:__init(title, handler, data)
	MenuItem.__init(self, title)
	self.handler = handler
	self.data = data
end

function PlayerCmd.create(title, callback, val, args)
	check.func(callback)
	if args == nil then
		args = {}
	end

	args.callback = callback
	args.value = val

	return PlayerCmd(title, do_request, args)
end

function PlayerCmd:draw(gid, parent, player)
	self.gid = gid
	if player then
		self.data.name = player.name
	end
	self.path = addGroupCmd(self.gid, self.title, parent.path,
				self.handler, self.data)
end

function PlayerCmd:remove()
	removeGroupItem(self.gid, self.path)
	self.path = nil
	self.gid = nil
	if self.data then
		self.data.name = nil
	end
end

local PlayerMenu = class("PlayerMenu", MenuItem)
function PlayerMenu:__init(title)
	MenuItem.__init(self, title)
	self.children = {}
end

--- Write the menu and display to player
function PlayerMenu:draw(gid, parent, player)
	self.gid = gid
	self.path = addGroupMenu(self.gid, self.title, parent.path)

	for _, entry in ipairs(self.children) do
		entry:draw(self.gid, self, player)
	end
end

--- Remove the menu and all children.
function PlayerMenu:remove()
	self:clear()
	self.children = {}
	removeGroupItem(self.gid, self.path)
	self.path = nil
	self.gid = nil
end

--- Clear the menu of all entries but do not destroy the root menu item.
-- Reverse loop over all menu entries removing children first.
function PlayerMenu:clear()
	for i = #self.children, 1, -1 do
		self.children[i]:remove()
	end
end

function PlayerMenu:deleteAll()
	for i = #self.children, 1, -1 do
		self.children[i]:remove()
		table.remove(self.children, i)
	end
end

--- Remove a specific menu entry.
--
-- @param entry the entry we want to delete
function PlayerMenu:delete(entry)
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

function PlayerMenu:addMenu(title)
	local menu = PlayerMenu(title)
	table.insert(self.children, menu)
	return menu
end

function PlayerMenu:addCmd(title, handler, data)
	local cmd = PlayerCmd(title, handler, data)
	table.insert(self.children, cmd)
	return cmd
end

function PlayerMenu:addRqstCmd(title, callback, val, args)
	local cmd = PlayerCmd.create(title, callback, val, args)
	table.insert(self.children, cmd)
	return cmd
end

local _pm = {}
_pm.Menu = PlayerMenu
_pm.Cmd  = PlayerCmd

return _pm
