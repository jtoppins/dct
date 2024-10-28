#!/usr/bin/lua

require 'busted.runner'()
require("os")
require("libs")
require("testlibs")

describe("validate stub environment", function()
	test("verify lfs.writedir()", function()
		local testpath = libs.utils.join_paths(lfs.dct_testdata,
							"savedgames")..libs.utils.sep
		assert.is.equal(lfs.writedir(), testpath)
	end)
	test("verify lfs.tempdir()", function()
		local testpath = libs.utils.join_paths(lfs.dct_testdata,
							"mission")
		assert.is.equal(lfs.tempdir(), testpath)
	end)
	test("verify lfs.currentdir()", function()
		local testpath = libs.utils.join_paths(lfs.dct_testdata,
							"gamedir")
		assert.is.equal(lfs.currentdir(), testpath)
	end)
end)
