#!/usr/bin/lua

require("os")
require("dcttestlibs")
local utils = require("libs.utils")

local testpath = lfs.dct_testdata
assert(lfs.writedir() == testpath,
	"lfs.writedir() incorrect got '"..lfs.writedir().."' expected '"..
	testpath.."'")

testpath = lfs.dct_testdata..utils.sep.."mission"
assert(lfs.tempdir() == testpath,
	"lfs.writedir() incorrect got '"..lfs.tempdir().."' expected '"..
	testpath.."'")

testpath = lfs.dct_testdata..utils.sep.."test.stm"
local rc = pcall(dofile, testpath)
assert(rc, "failed parsing of: "..testpath)

testpath = lfs.dct_testdata..utils.sep.."test.dct"
rc = pcall(dofile, testpath)
assert(rc, "failed parsing of: "..testpath)

assert(staticTemplate ~= nil)
assert(metadata ~= nil)
