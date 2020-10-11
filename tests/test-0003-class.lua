#!/usr/bin/lua

require("os")
require("io")
local class = require("libs.class")
--local json  = require("libs.json")
local instance

local A = class()
function A:__init()
    self.a = 2
    self.b = 3
end

function A.instance()
    if instance ~= nil then
        --print("instance set")
        return instance
    end
    instance = A()
    --print("should run once")
    return instance
end

local function main()
    local a = A.instance()
    local b = A.instance()
    b.b = 5
    assert(a == b, "singleton broken?")
    --print("a: "..json:encode_pretty(a))
    --print("b: "..json:encode_pretty(b))
    --print("a: "..tostring(a).."; b: "..tostring(b)..
    --    "; instance: "..tostring(instance))
end

os.exit(main())
