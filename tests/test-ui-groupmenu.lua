#!/usr/bin/lua

require("dcttestlibs")
require("dct")

-- Since groupmenu is added by the Theater, we just get a Theater
-- instance and then cook up an event to call the theater DCS
-- event handler with.

local testcmds = {
	[1] = {
		["event"] = {
			["id"]        = world.event.S_EVENT_BIRTH,
			["initiator"] = Unit("player1"),
		},
		["assert"] = true,
		["expect"] = "theater status and mission management available"
			.." in F10 menu",
	},
}

local function main()
	local theater = dct.Theater.getInstance()
	for _, data in ipairs(testcmds) do
		trigger.action.setmsgbuffer(data.expect)
		trigger.action.setassert(data.assert)
		theater:onEvent(data.event)
	end
	return 0
end

os.exit(main())
