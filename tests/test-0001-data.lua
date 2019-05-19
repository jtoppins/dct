#!/usr/bin/lua

local rc = pcall(dofile, "./data/test.stm")
assert(rc, "parsing of test.stm failed")
rc = pcall(dofile, "./data/test.dct")
assert(rc, "parsing of test.dct failed")

assert(staticTemplate ~= nil)
assert(metadata ~= nil)
