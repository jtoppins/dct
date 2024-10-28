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
	"libs",
}

files["src/dct/settings.lua"] = { globals = {"dctserverconfig",} }
files["src/dct/Theater.lua"] = { globals = {"theatergoals", "dct"} }
files["tests/*"] = {
	ignore = {"143", },
	globals = {
		-- busted globals
		"describe",
		"test",
		"pending",
		"before_each",
		"insulate",

		-- DCT specific
		"dcttest",
	},
}
files["tests/testlibs/dcsstubs.lua"] = { globals = {"lfs",}, }
files["tests/testlibs/dcttest.lua"] = { globals = {"timer",}, }
