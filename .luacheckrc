codes = true
std   = "lua51"
jobs  = 3
self  = false
max_line_length = 80
max_cyclomatic_complexity = 10
read_globals = {
	-- common lua globals
	"loadlib",
	"lfs",
	"md5",

	-- DCS specific globals
	"net",
	"atmosphere",
	"country",
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
	"land",
	"SceneryObject",
	"AI",
	"Controller",
	"radio",
	"Weapon",
	"Airbase",

	-- DCT specific
	"dct",
}

files["mission/dct-mission-init.lua"] = {
	globals = {"dctsettings", "luapath", "dct",},
}
files["src/dct/settings.lua"] = { globals = {"dctserverconfig",} }
files["src/dct/Theater.lua"] = { globals = {"theatergoals", "dct"} }
files["src/dcttestlibs/dcsstubs.lua"] = {
	globals = {"lfs"},
	read_globals = {"socket",},
}
files["tests/test-0001-data.lua"] = {
	globals = {"staticTemplate", "metadata",}
}
files["tests/*"] = {
	globals = {"dctstubs", "dctcheck", "dct"},
}
