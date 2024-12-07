-- SPDX-License-Identifier: LGPL-3.0

--- System. Defines a base class for defining a system within DCT.
-- A System is generally a collection of functionality that can be
-- self contained and provide a service or data to another system
-- or agent in DCT.
-- @classmod dct.libs.System

require("libs")
local class = libs.classnamed

local sysmt = {}
function sysmt.__lt(self, other)
	return self._order < other._order
end

local System = libs.utils.override_ops(class("System"), sysmt)

--- Priority values systems can use to order themselves. Mainly
-- intended for external DCT scripts that can integrate with DCT.
System.PRIORITY = {
	["CORE"]  = 0*(2^4), -- 0x00
	["STATE"] = 1*(2^4), -- 0x10
	["INFRA"] = 2*(2^4), -- 0x20
	["ADDON"] = 3*(2^4), -- 0x30
}

--- Common alias names for systems that are required by DCT in general.
System.SYSTEMALIAS = {
	["RENDERER"]    = "Renderer", -- controls how and when assets are
				      --  spawned
	["ASSETMGR"]    = "AssetManager", -- gives access to all assets in DCT
	["REGIONMGR"]   = "RegionManager", -- gives access to all regions
					   --  defined in the theater
	["TICKETS"]     = "TicketSystem", -- defines end state win critera
	["PERSISTENCE"] = "SaveSystem", -- saves theater state
	["GENERATION"]  = "GenerationSystem", -- generates a new theater
	["MENU"]        = "MenuSystem",
}

System.SYSTEMORDER = {
	["TEMPLATEDB"]   = System.PRIORITY.CORE + 3,
	["ASSETMGR"]     = System.PRIORITY.CORE + 4,
	["WPNIMPACT"]    = System.PRIORITY.CORE + 5,
	["TICKETS"]      = System.PRIORITY.CORE + 6,
	["PERSISTENCE"]  = System.PRIORITY.STATE + 1,
	["MENU"]         = System.PRIORITY.INFRA + 2,
}

--- Constructor.
-- Is called inside of Theater:__init() for core systems or before the
-- Theater:initialize() method is called.
-- @tparam Theater theater reference to the owning Theater object.
-- @tparam number order sort order in which system methods should be executed
--         in, lower numbers mean those methods will get executed first.
-- @tparam string alias the system is also known by this name. The alias
--         string is used when the system should override functionality from
--         another system.
function System:__init(theater, order, alias)
	self._logger = dct.libs.Logger.getByName(self.__clsname)
	self._theater = theater
	self._order = order
	self._alias = alias or self.__clsname
	self.enabled = nil
	self.PRIORITY = nil
	self.SYSTEMALIAS = nil
	self.SYSTEMORDER = nil
end

--- Initialize.
-- Called in the Theater:initialize() method. This gives a system the ability
-- to do lazy initialization and separate object creation from initialization.
-- This method will be called after the DCS environment is up.
-- All systems that can be registered with the Theater will be by the time
-- this method is called. So if a reference to another system needs to be
-- cached for later use, this is the method to do it in. Inter-system
-- interaction should not be done now however, you should wait until the
-- start method as system initialization cannot be guaranteed.
function System:initialize()
end

--- Start.
-- Called in the Theater:start() method. Will notify the game a DCT theater
-- has started and call all System:start() methods registered with the Theater.
-- This method will be called after the DCS environment is up.
function System:start()
end

return System
