#!/usr/bin/lua

require("dcttestlibs")
require("dct")
local uidraw = require("dct.ui.draw")

local objs = {
	uidraw.Mark("text to all", {1,1,1}, true),
	uidraw.Mark("text to group", {1,2,3}, false,
		    uidraw.Mark.scopeType.GROUP, 123),
	uidraw.Mark("text to red", {1,2,3}, false,
		    uidraw.Mark.scopeType.COALITION, coalition.side.RED),
	uidraw.Line({{1,1,1}, {2,2,2}}),
	uidraw.PolyLine({{1,1,1},{2,2,2},{3,3,3}}),
	uidraw.Circle({1,1,1}, 10),
	uidraw.Rect({{1,1,1}, {2,2,2}}),
	uidraw.Quad({{1,1,1}, {2,2,2}, {3,3,3}, {4,4,4}}),
	uidraw.Text({1,1,1}, "text"),
	uidraw.Arrow({{1,1,1}, {2,2,2}}),
}

local function main()
	for _, obj in ipairs(objs) do
		obj:draw()
		obj:remove()
	end
	return 0
end

os.exit(main())
