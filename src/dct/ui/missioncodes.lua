-- SPDX-License-Identifier: LGPL-3.0

--- Creates all menu entries necessary to input a mission code
-- from the radio menu UI.

local dctenum = require("dct.enum")
local Mission = require("dct.libs.Mission")
local PlayerMenu = require("dct.ui.PlayerMenu")

local function empty() end

local validFirstDigit = {}
for _, msn in pairs(Mission.typeData) do
	if msn.codeType then
		validFirstDigit[msn.codeType] = true
	end
end

local function createJoinCmds(root, halfCode)
	for digit3 = 1, 10 do
		if digit3 % 10 < 8 then
			local code = string.format("%s%d0", halfCode,
				digit3 % 10)
			root:addRqstCmd(string.format("Mission %s", code),
				dctenum.requestType.MISSION_JOIN, code)
		else
			root:addCmd("", empty)
		end
	end
end

local function createDigit2Menu(root, quarterCode)
	for digit2 = 1, 10 do
		if digit2 % 10 < 8 then
			local halfCode = string.format("%s%d", quarterCode,
				digit2 % 10)
			createJoinCmds(root:addMenu(string.format(
				"Mission %s__", halfCode)), halfCode)
		else
			root:addCmd("", empty)
		end
	end
end

--- Adds all valid mission code as sub items of root.
--
-- @param root [PlayerMenu] root menu entry which all new menu items are
--   children
local function addMissionCodes(root)
	assert(root:isa(PlayerMenu.Menu), "not a PlayerMenu class")
	for digit1 = 1, 10 do
		if validFirstDigit[digit1] then
			local quarterCode = tostring(digit1 % 10)
			createDigit2Menu(root:addmenu(string.format(
				"Mission %s___", quarterCode)), quarterCode)
		else
			root:addCmd("", empty)
		end
	end
end

return addMissionCodes
