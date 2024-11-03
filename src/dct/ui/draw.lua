-- SPDX-License-Identifier: LGPL-3.0

--- Draw objects on the F10 map.
-- A common library of functions that support drawing UI elements on
-- the F10 map.

require("libs")

local class    = libs.classnamed
local dctutils = require("dct.libs.utils")

local markindex = 10
local function get_new_id()
	markindex = markindex + 1
	return markindex
end

local DrawObject = class("DrawObject")
function DrawObject:__init()
	self.id = get_new_id()
	self.drawn = false
end

function DrawObject:__draw()
	assert(false, "not implemented error")
end

function DrawObject:draw()
	if self.drawn then
		return
	end

	self:__draw()
	self.drawn = true
end

function DrawObject:remove()
	trigger.action.removeMark(self.id)
	self.drawn = false
end


local Mark = class("Mark", DrawObject)
Mark.scopeType = {
	["COALITION"] = "coa",
	["GROUP"]     = "group",
	["ALL"]       = "all",
}

local mark_funcs = {
	[Mark.scopeType.COALITION] = trigger.action.markToCoalition,
	[Mark.scopeType.GROUP]     = trigger.action.markToGroup,
	[Mark.scopeType.ALL]       = trigger.action.markToAll,
}

function Mark:__init(text, pos, readonly, scope, scopeid)
	self.text = text
	self.pos = pos
	self.readonly = readonly or false
	self.scope = scope or Mark.scopeType.ALL
	self.func = mark_funcs[self.scope]
	self.scopeid = scopeid
	DrawObject.__init(self)
	self.scopeType = nil
end

function Mark:__draw()
	if self.scope == Mark.scopeType.ALL then
		self.func(self.id, self.text, self.pos, self.readonly)
	else
		self.func(self.id, self.text, self.pos, self.scopeid,
			self.readonly)
	end
end


local lineType = {
	["NOLINE"]   = 0,
	["SOLID"]    = 1,
	["DASHED"]   = 2,
	["DOTTED"]   = 3,
	["DOTDASH"]  = 4,
	["LONGDASH"] = 5,
	["TWODASH"]  = 6,
}

local colors = {
	["BLACK"]  = {0,0,0,1},
	["RED"]    = {1,0,0,1},
	["BLUE"]   = {0,0,1,1},
	["GREEN"]  = {0,1,0,1},
}

local function set_defaults(cls)
	cls.color = cls.color or colors.BLACK
	cls.linetype = cls.linetype or lineType.SOLID
	cls.readonly = cls.readonly or false
	cls.scope = cls.scope or dctutils.coalition.ALL
	cls.fillcolor = cls.fillcolor or colors.BLACK
end


local Line = class("Line", DrawObject)
function Line:__init(points, color, linetype, readonly, scope)
	assert(type(points) == "table" and #points == 2, "invalid points")
	self.points = points
	self.color = color
	self.linetype = linetype
	self.readonly = readonly
	self.scope = scope
	DrawObject.__init(self)
	set_defaults(self)
end

function Line:__draw()
        trigger.action.lineToAll(self.scope, self.id, self.points[1],
                self.points[2], self.color, self.linetype, self.readonly)
end


local PolyLine = class("PolyLine")
function PolyLine:__init(points, color, linetype, readonly, scope)
	self.drawn = false
	self.lines = {}
	for i = 1, #points - 1, 1 do
		table.insert(self.lines, Line({points[i], points[i+1]}, color,
						linetype, readonly, scope))
	end
end

function PolyLine:draw()
	if self.drawn then
		return
	end

	for _, line in ipairs(self.lines) do
		line:draw()
	end
	self.drawn = true
end

function PolyLine:remove()
	for _, line in ipairs(self.lines) do
		line:remove()
	end
	self.drawn = false
end


local Circle = class("Circle", DrawObject)
function Circle:__init(point, radius, color, fillcolor, linetype, readonly,
		scope)
	self.point = point
	self.radius = radius
	self.color = color
	self.fillcolor = fillcolor
	self.linetype = linetype
	self.readonly = readonly
	self.scope = scope
	DrawObject.__init(self)
	set_defaults(self)
end

function Circle:__draw()
        trigger.action.circleToAll(self.scope, self.id, self.point,
		self.radius, self.color, self.fillcolor, self.linetype,
		self.readonly)
end


local Rect = class("Rectangle", Line)
function Rect:__init(points, color, fillcolor, linetype, readonly, scope)
	self.fillcolor = fillcolor
	Line.__init(self, points, color, linetype, readonly, scope)
end

function Rect:__draw()
        trigger.action.rectToAll(self.scope, self.id, self.points[1],
                self.points[2], self.color, self.fillcolor, self.linetype,
		self.readonly)
end


local Quad = class("Quad", DrawObject)
function Quad:__init(points, color, fillcolor, linetype, readonly, scope)
	assert(type(points) == "table" and #points == 4, "invalid points")
	self.points = points
	self.color = color
	self.fillcolor = fillcolor
	self.linetype = linetype
	self.readonly = readonly
	self.scope = scope
	DrawObject.__init(self)
	set_defaults(self)
end

function Quad:__draw()
        trigger.action.quadToAll(self.scope, self.id,
		self.points[1], self.points[2], self.points[3], self.points[4],
		self.color, self.fillcolor, self.linetype, self.readonly)
end


local Text = class("Text", DrawObject)
function Text:__init(point, text, fontsize, color, fillcolor, readonly, scope)
	self.point = point
	self.text = text
	self.fontsize = fontsize or 12
	self.color = color
	self.fillcolor = fillcolor
	self.readonly = readonly
	self.scope = scope
	DrawObject.__init(self)
	set_defaults(self)
end

function Text:__draw()
        trigger.action.textToAll(self.scope, self.id, self.point,
		self.color, self.fillcolor, self.fontsize, self.readonly,
		self.text)
end

local Arrow = class("Arrow", Line)
function Arrow:__init(points, color, fillcolor, linetype, readonly, scope)
	self.fillcolor = fillcolor
	Line.__init(self, points, color, linetype, readonly, scope)
end

function Arrow:__draw()
        trigger.action.arrowToAll(self.scope, self.id, self.points[1],
                self.points[2], self.color, self.fillcolor, self.linetype,
		self.readonly)
end

return {
	["lineType"]   = lineType,
	["colors"]     = colors,
	["DrawObject"] = DrawObject,
	["Mark"]       = Mark,
	["Line"]       = Line,
	["PolyLine"]   = PolyLine,
	["Circle"]     = Circle,
	["Rect"]       = Rect,
	["Quad"]       = Quad,
	["Text"]       = Text,
	["Arrow"]      = Arrow,
}
