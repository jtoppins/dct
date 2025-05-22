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
		dcttest.fastForward(50)
	end)

	test("birth event and fuel usage", function()
		local unit, _ = dcttest.createPlayer("bobplayer")

		dcttest.setupRuntime()
		local t = dct.Theater.singleton()
		t:run()

		dcttest.setModelTime(10)
		dcttest.fastForward(30)
		dcttest.runEventHandlers({
			["id"]        = world.event.S_EVENT_BIRTH,
			["initiator"] = unit,
		})

		local amgr = t:getSystem(dct.libs.System.SYSTEMALIAS.ASSETMGR)
		local agent = amgr:getAsset(unit:getGroup():getName())

		dcttest.fastForward(30, 10)
		-- set fuel lower to simulate usage
		unit.fuel = .14
		dcttest.fastForward(30, 10)
		assert.is.equal(tostring(agent:getPlan():getGoal()),
				"RTB")
	end)
end)
