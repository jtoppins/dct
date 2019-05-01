--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides debug stats.
--]]

local class  = require("libs.class")
local Logger = require("dct.logger")

local stats = nil
local DebugStats = class()

function DebugStats.getDebugStats()
	if stats == nil then
		stats = DebugStats()
	end
	return stats
end

function DebugStats:__init()
	self.logger = Logger.getByName("debugstats")
	self.stats  = {}
end

function DebugStats:registerStat(name, val, title)
	assert(self.stats[name] == nil, "attempt to re-register stat")
	self.stats[name] = { ["value"] = val, ["title"] = title, }
end

function DebugStats:incstat(name, val)
	self.stats[name].value = self.stats[name].value + val
end

function DebugStats:log()
	self.logger:info("== info stats ==")
	for _, stat in pairs(self.stats) do
		self.logger:info("=> "..stat.title..": "..stat.value)
	end
end

return DebugStats
