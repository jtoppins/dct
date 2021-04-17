#!/usr/bin/lua

local vector = require("dct.libs.vector")

local function main()
    local a = vector.Vector2D({x=5,y=5})
	local b = vector.Vector2D({x=3,y=3})
	local c = vector.Vector2D({x=3,y=3})

	assert(7071 == math.floor(1000 * a:magnitude()), "magnitude broken?")
	assert(a ~= b, "vector inequality broken?")
	assert(c == b, "vector equality broken?")
	assert(1000 == math.ceil(vector.unitvec(a):magnitude() * 1000),
		"unit vector broken?")
	assert((a - b) == vector.Vector2D({x=2,y=2}),
		"subtraction broken?")
	assert((3 * a) == vector.Vector2D({x=15,y=15}), "scalar product broken?")
	assert((3 * a) / 3 == a, "scalar division broken?")
end

os.exit(main())
