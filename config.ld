project = "DCT"
title = "Dynamic Campaign Tools Documentation"
description = [[Mission scripting framework for persistent Digital Combat
Simulator (DCS) missions.]]
dir = "documentation"
format = "discount"
file = {
	"src/dct.lua",
	"src/dct",
}
kind_names = {
	topic = "Manual",
	module = "Reference",
}
topics = {
	"docs/quick-start.md",
	"docs/administrators.md",
	"docs/designer.md",
	"docs/playerui.md",
}

new_type("serverattr", "Server Settings")
new_type("tplattr", "Template Attributes")
