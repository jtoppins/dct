--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- vector math library
--]]

require("math")
local class = require("libs.class")
local utils = require("libs.utils")

local function override_ops(cls, mt)
	local curmt = getmetatable(cls) or {}
	curmt = utils.mergetables(curmt, mt)
	setmetatable(cls, curmt)
	return cls
end

-- 2D Vector Math
--
local Vector2D = class()
local mt2d = {}
function mt2d.__add(vec, rhs)
	assert(rhs.x ~= nil and rhs.y ~= nil,
		"value error: rhs value not a 2D vector")
	local v = {}
	v.x = vec.x + rhs.x
	v.y = vec.y + rhs.y
	return Vector2D(v)
end

function mt2d.__sub(vec, rhs)
	assert(rhs.x ~= nil and rhs.y ~= nil,
		"value error: rhs value not a 2D vector")
	local v = {}
	v.x = vec.x - rhs.x
	v.y = vec.y - rhs.y
	return Vector2D(v)
end

function mt2d.__mul(vec, rhs)
	assert(type(rhs) == "number", "value error: rhs not a number")
	local v = {}
	v.x = vec.x * rhs
	v.y = vec.y * rhs
	return Vector2D(v)
end

function mt2d.__div(vec, rhs)
	assert(type(rhs) == "number", "value error: rhs not a number")
	local v = {}
	v.x = vec.x / rhs
	v.y = vec.y / rhs
	return Vector2D(v)
end

function mt2d.__eq(vec, rhs)
	return vec.x == rhs.x and vec.y == rhs.y
end

function Vector2D:__init(obj)
	self.x = obj.x
	if obj.z then
		self.y = obj.z
	else
		self.y = obj.y
	end
	override_ops(self, mt2d)
end

function Vector2D.create(x, y)
	local t = { ["x"] = x, ["y"] = y, }
	return Vector2D(t)
end

function Vector2D:raw()
	return { ["x"] = self.x, ["y"] = self.y }
end

function Vector2D:magnitude()
	return math.sqrt(self.x^2 + self.y^2)
end


-- 3D Vector Math
--
local Vector3D = class()
local mt3d = {}
function mt3d.__add(vec, rhs)
	assert(rhs.x ~= nil and rhs.y ~= nil and rhs.z ~= nil,
		"value error: rhs value not a 3D vector")
	local v = {}
	v.x = vec.x + rhs.x
	v.y = vec.y + rhs.y
	v.z = vec.z + rhs.z
	return Vector3D(v)
end

function mt3d.__sub(vec, rhs)
	assert(rhs.x ~= nil and rhs.y ~= nil and rhs.z ~= nil,
		"value error: rhs value not a 3D vector")
	local v = {}
	v.x = vec.x - rhs.x
	v.y = vec.y - rhs.y
	v.z = vec.z - rhs.z
	return Vector3D(v)
end

function mt3d.__mul(vec, rhs)
	assert(type(rhs) == "number", "value error: rhs not a number")
	local v = {}
	v.x = vec.x * rhs
	v.y = vec.y * rhs
	v.z = vec.z * rhs
	return Vector3D(v)
end

function mt3d.__div(vec, rhs)
	assert(type(rhs) == "number", "value error: rhs not a number")
	local v = {}
	v.x = vec.x / rhs
	v.y = vec.y / rhs
	v.z = vec.z / rhs
	return Vector3D(v)
end

function mt3d.__eq(vec, rhs)
	return vec.x == rhs.x and vec.y == rhs.y and vec.z == rhs.z
end

function Vector3D:__init(obj, height)
	self.x = obj.x

	if obj.z then
		self.y = obj.y
		self.z = obj.z
	else
		self.y = height or obj.alt or 0
		self.z = obj.y
	end
	override_ops(self, mt3d)
end

function Vector3D.create(x, y, height)
	local t = { ["x"] = x, ["y"] = height, ["z"] = y, }
	return Vector3D(t)
end

function Vector3D:raw()
	return { ["x"] = self.x, ["y"] = self.y, ["z"] = self.z }
end

function Vector3D:magnitude()
	return math.sqrt(self.x^2 + self.y^2 + self.z^2)
end

-- Vector Math Library table
--
local vmath = {}
vmath.Vector2D = Vector2D
vmath.Vector3D = Vector3D
function vmath.distance(vec1, vec2)
	local v = vec2 - vec1
	return v:magnitude()
end

function vmath.unitvec(vec)
	return vec / vec:magnitude()
end

function vmath.dot(U, V)
	assert((U:isa(Vector2D) and V:isa(Vector2D)) or
		   (U:isa(Vector3D) and V:isa(Vector3D)),
		   "vectors are not of the same order")
	local sum = 0

	for _, n in ipairs({'x', 'y', 'z'}) do
		if U[n] and V[n] then
			sum = sum + (U[n] * V[n])
		end
	end
	return sum
end

return vmath
