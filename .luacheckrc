codes = true
std   = "lua51"
jobs  = 3
self  = false
max_cyclomatic_complexity = 10
read_globals = {
	-- common lua globals
	"lfs",
	"md5",

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

files["mission/dct-mission-init.lua"] = {
	globals = {"dctsettings", "luapath",},
}
files["src/dct/Region.lua"] = { globals = {"region",} }
files["src/dct/settings.lua"] = { globals = {"dctserverconfig",} }
files["src/dct/Template.lua"] = {
	globals = {"staticTemplate", "metadata",},
}
files["src/dct/Theater.lua"] = { globals = {"theatergoals",} }
files["src/dcttestlibs/dcsstubs.lua"] = {
	globals = {"lfs"},
	read_globals = {"socket",},
}
files["tests/test-0001-data.lua"] = {
	globals = {"staticTemplate", "metadata",}
}
files["tests/*"] = {
	globals = {"dctsettings", "dctcheck", },
}
