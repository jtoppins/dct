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
	"coalition",
	"world",
	"timer",

	-- DCT specific
	"dctsettings",
	"dct",
}

files["src/dct/region.lua"] = { globals = {"region",} }
files["src/dct/settings.lua"] = { globals = {"dctserverconfig",} }
files["src/dct/template.lua"] = {
	globals = {"staticTemplate", "metadata",},
	ignore  = {"key",},
}
files["src/dct/theater.lua"] = { globals = {"theatergoals",} }
files["tests/testlibs/dcsstubs.lua"] = {
	globals = {"lfs"},
	read_globals = {"socket",},
	ignore = {"showbox",},
}
files["tests/test-0001-data.lua"] = {
	globals = {"staticTemplate", "metadata",}
}
files["tests/*"] = {
	globals = {"test", "coalition", "dctsettings",},
}
