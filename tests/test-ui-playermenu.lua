#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local Template = require("dct.templates.Template")
local Agent = require("dct.assets.Agent")
local PlayerMenu = require("dct.ui.PlayerMenu")

local result1 = [[Group (50):
- Top1
    - Menu1-1
        - cmd1-1-1
        - cmd1-1-2
- Top2
    - cmd2-1
    - cmd2-2
]]
local result2 = [[Group (50):
- Top1
    - Menu1-1
        - cmd1-1-1
        - cmd1-1-2
- Top2
    - cmd2-1
]]

local function main()
	local playertpl = Template({
		["objtype"]   = "player",
		["name"]      = "Player 1",
		["coalition"] = "blue",
		["cost"]      = 5,
		["desc"]      = "Player group",
		["location"]  = { ["x"] = 0, ["y"] = 0, },
		["tpldata"]   = {},
		["groupId"]   = 50,
		["basedat"]   = "does-not-exist",
		["overwrite"] = false,
		["rename"]    = false,
	})
	local Player = Agent()
	Player.getTemplate = function () return playertpl end
	Player.name = playertpl.name
	Player.type = playertpl.objtype
	Player.owner = playertpl.coalition
	Player.desc = playertpl:genDesc()
	Player:setup()
	local gid = Player:getDescKey("groupId")
	local top1 = PlayerMenu.Menu("Top1", nil, Player)
	local sub1 = top1:addMenu("Menu1-1")
	sub1:addCmd("cmd1-1-1")
	sub1:addCmd("cmd1-1-2")
	local top2 = PlayerMenu.Menu("Top2", nil, Player)
	top2:addCmd("cmd2-1")
	local cmd = top2:addCmd("cmd2-2")
	assert(missionCommands.printGroupMenu(gid) == result1)
	cmd:destroy()
	assert(missionCommands.printGroupMenu(gid) == result2)
	return 0
end

os.exit(main())
