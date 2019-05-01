--[[
Top level initialization and kickoff package

----
init function initializes game state

----
start/run function starts the DCT engine

--]]

local theater = require("dct.theater")

local function init(dctsettings)
	local theaterPath = dctsettings.templatedir or
						lfs.writedir() .. "DctTemplates\\PhaseOne"

	local t = theater.Theater(theaterPath)
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
end

return init
