require("lfs")

function lfs.writedir()
	return "./data"
end

function lfs.tempdir()
	return "./data"
end

env = {}
env.mission = {}
env.mission.theatre = "Test Theater"
env.mission.sortie  = "test mission"
function env.getValueDictByKey(s)
	return s
end

function env.warning(msg, showbox)
	print(msg)
end

Unit = {}
Unit.Category = {
	["AIRPLANE"]    = 0,
	["HELICOPTER"]  = 1,
	["GROUND_UNIT"] = 2,
	["SHIP"]        = 3,
	["STRUCTURE"]   = 4,
}
