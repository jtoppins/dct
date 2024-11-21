#!/usr/bin/lua

require 'busted.runner'()
require("os")
require("libs")
require("testlibs")

describe("validate dct.Theater", function()
	test("init", function()
		dcttest.setupRuntime()
		local t = dct.Theater.singleton()
		t:run()

		dcttest.setModelTime(10)
		for _ = 1,100,1 do
			dcttest.runSched()
			dcttest.addModelTime(3)
		end
	end)
end)
