-- SPDX-License-Identifier: LGPL-3.0

--- vector math library
-- @module dct.libs.vector
-- @alias vmath

require("math")
require("libs")

local class = libs.class
local utils = libs.utils

-- we need to keep this version due to how object references work.
-- @see libs.utils.override_ops for the common function.
local function override_ops(cls, mt)
	local curmt = getmetatable(cls) or {}
	curmt = utils.mergetables(curmt, mt)
	setmetatable(cls, curmt)
	return cls
end

--- 2D Vector Math.
-- Metamethods support scalar addition, subtraction, multiplication,
-- and division. There is also support for strict equality and string
-- serialization.
-- @type Vector2D
local Vector2D = class()
local mt2d = {}
function mt2d.__add(vec, rhs)
	if type(rhs) == "number" then
		rhs = { x = rhs, y = rhs }
	end
	assert(rhs.x ~= nil and rhs.y ~= nil,
		"value error: rhs value not a 2D vector")
	local v = {}
	v.x = vec.x + rhs.x
	v.y = vec.y + rhs.y
	return Vector2D(v)
end

function mt2d.__sub(vec, rhs)
	if type(rhs) == "number" then
		rhs = { x = rhs, y = rhs }
	end
	assert(rhs.x ~= nil and rhs.y ~= nil,
		"value error: rhs value not a 2D vector")
	local v = {}
	v.x = vec.x - rhs.x
	v.y = vec.y - rhs.y
	return Vector2D(v)
end

function mt2d.__mul(lhs, vec)
	assert(type(lhs) == "number", "value error: __mul lhs not a number")
	local v = {}
	v.x = lhs * vec.x
	v.y = lhs * vec.y
	return Vector2D(v)
end

function mt2d.__div(vec, rhs)
	assert(type(rhs) == "number", "value error: __div rhs not a number")
	local v = {}
	v.x = vec.x / rhs
	v.y = vec.y / rhs
	return Vector2D(v)
end

function mt2d.__eq(vec, rhs)
	return vec.x == rhs.x and vec.y == rhs.y
end

function mt2d.__tostring(vec)
	return string.format("(%g, %g)", vec.x, vec.y)
end

--- Constructor. Create Vector2D object from `obj`. The constructor
-- never fails and if no coordinate elements are detected all values
-- will be zero.
-- @param obj can be a 2d or 3d object of DCS or Vector class origin
--     the constructor will select the correct fields to convert to
--     a normal 2d object based on some DCS particulars.
function Vector2D:__init(obj)
	self.x = obj.x or 0
	if obj.z then
		self.y = obj.z
	else
		self.y = obj.y or 0
	end
	override_ops(self, mt2d)
	self.create = nil
end

--- Constructor. Create Vector2D object from `x` and `y` coordinates.
-- The constructor never fails and if no coordinate elements are detected
-- all values will be zero.
function Vector2D.create(x, y)
	local t = { ["x"] = x, ["y"] = y, }
	return Vector2D(t)
end

--- Create a raw lua table with 'x' and 'y' keys. Used for passing to
-- DCS functions.
function Vector2D:raw()
	return { ["x"] = self.x, ["y"] = self.y }
end

--- Calculate the vector magnitude.
function Vector2D:magnitude()
	return math.sqrt(self.x^2 + self.y^2)
end

--- Rotate the 2D vector. Using standard right-hand rule rotation,
-- counter-clockwise for positive values of theta.
function Vector2D:rotate(theta)
	local x = self.x * math.cos(theta) - self.y * math.sin(theta)
	local y = self.x * math.sin(theta) + self.y * math.cos(theta)
	self.x = x
	self.y = y
end

--- 3D Vector Math
-- Metamethods support scalar addition, subtraction, multiplication,
-- and division. There is also support for strict equality and string
-- serialization.
-- @type Vector3D
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

function mt3d.__mul(lhs, vec)
	assert(type(lhs) == "number", "value error: __mul lhs not a number")
	local v = {}
	v.x = lhs * vec.x
	v.y = lhs * vec.y
	v.z = lhs * vec.z
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

function mt3d.__tostring(vec)
	return string.format("(%g, %g, %g)", vec.x, vec.y, vec.z)
end

--- Constructor. Create Vector3D object from `obj` and a `height`
-- above/below sea-level. The constructor never fails and if no
-- coordinate elements are detected all values will be zero.
-- @param obj can be a 2d or 3d object of DCS or Vector class origin
--     the constructor will select the correct fields to convert to
--     a normal 3d object based on some DCS particulars.
-- @param height above/below sea-level, will override any height in
--     `obj` otherwise can be nil for auto-detection.
function Vector3D:__init(obj, height)
	self.x = obj.x or 0

	if obj.z then
		self.y = height or obj.y or 0
		self.z = obj.z
	else
		self.y = height or obj.alt or 0
		self.z = obj.y or 0
	end
	override_ops(self, mt3d)
	self.create = nil
end

--- Constructor. Create Vector3D object from `x`, `y`, and a `height`
-- above/below sea-level. The constructor never fails and if no
-- coordinate elements are detected all values will be zero.
function Vector3D.create(x, y, height)
	local t = { ["x"] = x, ["y"] = height, ["z"] = y, }
	return Vector3D(t)
end

--- Create a raw lua table with 'x', 'y', and 'z' keys. Used for passing
-- to DCS functions.
function Vector3D:raw()
	return { ["x"] = self.x, ["y"] = self.y, ["z"] = self.z }
end

--- Calculate the vector magnitude.
function Vector3D:magnitude()
	return math.sqrt(self.x^2 + self.y^2 + self.z^2)
end

--- Vector Functions
-- @section vector

local vmath = {}
vmath.Vector2D = Vector2D
vmath.Vector3D = Vector3D

--- Calculate the distance between `vec1` and `vec2`.
-- @tparam Vector2D|Vector3D vec1 first vector.
-- @tparam Vector2D|Vector3D vec2 second vector.
-- @treturn number distance between vec1 and vec2
function vmath.distance(vec1, vec2)
	local v = vec2 - vec1
	return v:magnitude()
end

--- Calculate the unit vector of `vec`.
-- @tparam Vector2D|Vector3D vec vector to calculate the unit vector of.
-- @treturn Vector unit vector of vec
function vmath.unitvec(vec)
	return vec / vec:magnitude()
end

--- Dot product of vectors U and V. The vectors must be of the same
-- order.
-- @tparam Vector2D|Vector3D U
-- @tparam Vector2D|Vector3D V
-- @treturn number scalar value
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

--- Angle between 2D vectors A and B in radians
-- @tparam Vector2D A
-- @tparam Vector2D B
-- @treturn number angle in radians
function vmath.angle(A, B)
	local dot = vmath.dot(A, B)
	return math.acos(dot / (A:magnitude() * B:magnitude()))
end

return vmath
