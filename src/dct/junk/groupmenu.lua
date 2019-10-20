--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Handles applying a F10 menu UI to player groups
--]]


missionCommands.addCommandForGroup(groupID, name, path, func, arg)
missionCommands.addSubMenuForGroup(groupID, name, path)
missionCommands.removeItemForGroup(groupID, path)

local class = require("libs.class")

function dct.utils.findAllHumanGroups()
end

function requestMission(groupName, missiontype)
end

function assignMission(groupName, MissionObj)
end

local RequestMissionCmd = class(Command)
local Mission = class()
local HumanGroup = class()
menu
mission

__init(Group, Theater)
missionAssign(mission)
missionAbort()
missionRequest()

local Menu = class()
function Menu:__init(parent)
end

function Menu:addCommand(name, func, arg)
end

function Menu:addMenu(name)
end

root = Menu()

requestmission = Menu()

local HumanGroup = class()
