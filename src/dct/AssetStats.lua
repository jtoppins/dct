--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a side's strategic theater commander.
--]]

local class   = require("libs.class")
local utils   = require("libs.utils")
local enum    = require("dct.enum")
local Logger  = require("dct.Logger").getByName("AssetStats")

--[[
--  Storage:
--    [<assettype>] = {
--	      ["alive"]   = #,
--	      ["nominal"] = #,
--    }
--    ...
--]]
--
-- TODO: this doesn't seem like it will work, need to move init out of
--   add(), need a set() function, and the 'stats' are by name instead
--   of by id. Accessing a stat should just be a request which can assume
--   a value is always returned, no testing of nil. Do not allow exposing
--   the internal storage format.

local BaseStats = class()

function BaseStats:__init(stattbl)
	self.stats = stattbl
end

function BaseStats:add(stat, val)
	self.stats[stat] = self.stats[stat] + val
	return self.stats[stat]
end

function BaseStats:decrement(stat)
	return self:add(stat, -1)
end

function BaseStats:increment(stat)
	return self:add(stat, 1)
end

function BaseStats:get(stat)
	return self.stats[stat]
end

function BaseStats:set(stat, val)
	self.stats[stat] = val
end


local AssetStats = class(BaseStats)

function AssetStats:__init()
	local tpltbl = {
		[AssetStats.stat.ALIVE]   = 0,
		[AssetStats.stat.NOMINAL] = 0,
	}
	local statstbl = {}

	for _, v in pairs(enum.assetType) do
		statstbl[v] = utils.deepcopy(tpltbl)
	end
	BaseStats.__init(self, statstbl)
end

function AssetStats:add(assettype, stat, val)
	self.stats[assettype][stat] = self.stats[assettype][stat] + val
	return self.stats[assettype][stat]
end

function AssetStats:decrement(assettype, stat)
	return self:add(assettype, stat, -1)
end

function AssetStats:increment(assettype, stat)
	return self:add(assettype, stat, 1)
end

function AssetStats:get(assettype, stat)
	return self.stats[assettype][stat]
end

function AssetStats:set(assettype, stat, val)
	self.stats[assettype][stat] = val
end

AssetStats.stat = {
	["ALIVE"]   = "alive",
	["NOMINAL"] = "nominal",
}

return AssetStats
