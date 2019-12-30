codes = true
std   = "lua51"
jobs  = 3
self  = false
read_globals = {
	-- common lua globals
	"lfs",

	-- DCS specific globals
	"env",
	"Unit",
	"Object",
	"StaticObject",
	"Group",
	"coalition",
	"world",
	"timer",
	"trigger",
	"missionCommands",
	"coord",

	-- DCT specific
	"dctsettings",
	"dct",
}

files["src/dct/Region.lua"] = { globals = {"region",} }
files["src/dct/settings.lua"] = { globals = {"dctserverconfig",} }
files["src/dct/Template.lua"] = {
	globals = {"staticTemplate", "metadata",},
}
files["src/dct/Theater.lua"] = { globals = {"theatergoals",} }
files["tests/testlibs/dcsstubs.lua"] = {
	globals = {"lfs"},
	read_globals = {"socket",},
	ignore = {"showbox",},
}
files["tests/test-0001-data.lua"] = {
	globals = {"staticTemplate", "metadata",}
}
files["tests/*"] = {
	globals = {"dctsettings", "dctcheck", },
}
