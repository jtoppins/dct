-- SPDX-License-Identifier: LGPL-3.0

-- A general player menu and request system that allows other systems
-- to;
-- 1. define the top level menus for the F10 other DCS menu system
-- 2. allow other systems to register a top level menu and request
--    handler with the system
-- 3. automatically handle dispatch of requests and automatic redraw
--    of menu entries

--- Player UI Menus

require("libs")

local class      = libs.classnamed
local System     = require("dct.libs.System")
local PlayerMenu = require("dct.ui.PlayerMenu")
local WS         = require("dct.agent.worldstate")
local MENULIMIT  = 10

local MenuSystem = class("MenuSystem", System)

MenuSystem.enabled = true

MenuSystem.menutype = {
	["EMPTY"]      = MENULIMIT + 1,
	["SCRATCHPAD"] = 1,
	["INTEL"]      = 2,
	["GROUNDCREW"] = 3,
	["MISSION"]    = 4,
	["TANKER"]     = 5,
	["CUSTOM6"]    = 6,
	["CUSTOM7"]    = 7,
	["CUSTOM8"]    = 8,
	["CUSTOM9"]    = 9,
}

function MenuSystem.empty() end

function MenuSystem:__init(theater)
	System.__init(self, theater, System.SYSTEMORDER.MENU,
		      System.SYSTEMALIAS.MENU)
	self.menu = {}
	self:addMenu(MenuSystem.menutype.INTEL, "Intel")
	self:addMenu(MenuSystem.menutype.GROUNDCREW, "Ground Crew")
	self:addMenu(MenuSystem.menutype.MISSION, "Mission")
	self:addCmd(MenuSystem.menutype.TANKER, "Tanker (not implemented)",
		    MenuSystem.empty)
end

--- Initialize the system.
function MenuSystem:initialize()
	local groundcrew = self:getMenu(MenuSystem.menutype.GROUNDCREW)
	groundcrew:addCmd("Homebase Status (not implemented)", MenuSystem.empty)

	local mission = self:getMenu(MenuSystem.menutype.MISSION)
	mission:addCmd("Request", MenuSystem.empty)
	mission:addCmd("Join (scratchpad)", MenuSystem.empty)
end

--- Start the system.
function MenuSystem:start()
	print(libs.json:encode_pretty(self.menu))
	-- TODO: not sure if we should monitor for player spawn
	-- events and add the menu then. Or tie the playersensor and
	-- this system together
end

function MenuSystem:getMenu(order)
	return self.menu[order]
end

--- Add a new top level menu to the menu list
function MenuSystem:addMenu(order, title, force)
	if not force and self.menu[order] ~= nil then
		-- TODO: emit log message
		return
	end
	self.menu[order] = PlayerMenu.Menu(title, create)
	return self.menu[order]
end

--- Add a new top level command to the menu list
function MenuSystem:addCmd(order, title, handler, force)
	if not force and self.menu[order] ~= nil then
		-- TODO: emit log message
		return
	end
	self.menu[order] = PlayerMenu.Cmd(title, handler)
end

--- Apply F10 other menu system to a player agent.
function MenuSystem:apply(player)
	local menutbl = {}
	for idx = 1, MENULIMIT do
		local menu = self.menu[idx]
		local newmenu, id

		if menu == nil then
			newmenu = PlayerMenu.Cmd("", MenuSystem.empty)
			id = MenuSystem.menutype.EMPTY
		else
			newmenu = menu:clone()
			id = idx
		end

		menutbl[idx] = {
			["menu"] = newmenu,
			["id"] = id
		}
	end

	local fact = WS.Facts.PlayerMenu(menutbl)
	player:setFact(fact.__clsname, fact)
end

return MenuSystem
