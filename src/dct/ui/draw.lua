-- SPDX-License-Identifier: LGPL-3.0

--- Draw objects on the F10 map.
-- A common library of functions that support drawing UI elements on
-- the F10 map.
-- @module dct.ui.draw

require("libs")

local class    = libs.classnamed
local dctutils = require("dct.libs.utils")

local markindex = 10
local function get_new_id()
	markindex = markindex + 1
	return markindex
end

--- Base class for a drawable object.
-- This class must be inherited by a concrete class that needs to
-- draw objects in DCS.
-- @type DrawObject
local DrawObject = class("DrawObject")

--- Constructor.
function DrawObject:__init()
	self.id = get_new_id()
	self.drawn = false
end

--- Pure abstract method. Inheriting objects must override this
-- method to draw the object.
function DrawObject:__draw()
	assert(false, "not implemented error")
end

--- Public method to draw the object.
function DrawObject:draw()
	if self.drawn then
		return
	end

	self:__draw()
	self.drawn = true
end

--- Remove the drawn object from DCS.
function DrawObject:remove()
	trigger.action.removeMark(self.id)
	self.drawn = false
end


--- Draws a mark object on the DCS F10 map.
-- @type Mark
local Mark = class("Mark", DrawObject)

--- The scope in which the mark can be viewed.
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

--- Constructor.
-- @tparam string text contained in the mark.
-- @tparam table pos 2d position where the mark should be placed.
-- @tparam bool readonly can players edit the mark
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
-- @tparam number scopeid the id specifying the scope, example:
--        if scope=coalition then scopeid=coalition.side.RED.
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

--- Draw a line on the F10 map.
-- @type Line
local Line = class("Line", DrawObject)

--- Constructor.
-- @tparam list points lua list of 2d points, only the first 2 points will
--        be used.
-- @tparam table color color of the line
-- @tparam number linetype type of line; dashed, dotted, solid, etc
-- @tparam bool readonly can players edit the line
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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

--- Draw a poly line on the F10 map.
-- @type PolyLine
local PolyLine = class("PolyLine")

--- Constructor.
-- @tparam table points lua list of 2d points.
-- @tparam table color color of the line
-- @tparam number linetype type of line; dashed, dotted, solid, etc
-- @tparam bool readonly can players edit the line
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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

--- Draw a circle on the F10 map.
-- @type Circle
local Circle = class("Circle", DrawObject)

--- Constructor.
-- @tparam table point center of the circle.
-- @tparam number radius radius of circle
-- @tparam table color color of the circumference of the circle
-- @tparam table fillcolor fill color inside the circle
-- @tparam number linetype type of line; dashed, dotted, solid, etc
-- @tparam bool readonly can players edit the circle
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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

--- Draw a rectangle on the F10 map.
-- @type Rect
local Rect = class("Rectangle", Line)

--- Constructor.
-- @tparam table points points of the rectangle only the upper left and lower
--         right corners of the rectangle need to be defined. This is
--         an axis aligned rectangle. Use Quad to draw non-axis aligned
--         quadrilaterals.
-- @tparam table color color of the line defining the rectangle.
-- @tparam table fillcolor fill color inside the rectangle.
-- @tparam number linetype type of line; dashed, dotted, solid, etc.
-- @tparam bool readonly can players edit the circle
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
function Rect:__init(points, color, fillcolor, linetype, readonly, scope)
	self.fillcolor = fillcolor
	Line.__init(self, points, color, linetype, readonly, scope)
end

function Rect:__draw()
        trigger.action.rectToAll(self.scope, self.id, self.points[1],
                self.points[2], self.color, self.fillcolor, self.linetype,
		self.readonly)
end

--- Draw a quadrilateral on the F10 map.
-- @type Quad
local Quad = class("Quad", DrawObject)

--- Constructor.
-- @tparam table points four corners of the quadrilateral.
-- @tparam table color color of the line defining the object.
-- @tparam table fillcolor fill color inside the object.
-- @tparam number linetype type of line; dashed, dotted, solid, etc.
-- @tparam bool readonly can players edit the circle
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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

--- Draw text on the F10 map.
-- @type Text
local Text = class("Text", DrawObject)

--- Constructor.
-- @tparam table point start point of the text.
-- @tparam string text the text string.
-- @tparam number fontsize font size.
-- @tparam table color color of text.
-- @tparam table fillcolor fill color inside the object.
-- @tparam bool readonly can players edit the circle
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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

--- Draw an arrow on the F10 map.
-- @type Arrow
local Arrow = class("Arrow", Line)

--- Constructor.
-- @tparam table points 2 points.
-- @tparam table color color of the line defining the object.
-- @tparam table fillcolor fill color inside the object.
-- @tparam number linetype type of line; dashed, dotted, solid, etc.
-- @tparam bool readonly can players edit the circle
-- @tparam Mark.scopeType scope if the scope can only be seen
--        by a specific coalition or group.
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
