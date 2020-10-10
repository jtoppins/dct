--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a stats class to manage tracking various metrics.
--]]

local class   = require("libs.class")
--local utils   = require("libs.utils")
--local Logger  = require("dct.Logger").getByName("Stats")

local Stats = class()
function Stats:__init(stattbl)
	self.stats = {}

	for _,v in pairs(stattbl or {}) do
		self:register(unpack(v))
	end

	--print(require("libs.json"):encode_pretty(self))
end

function Stats:register(id, val, name)
	self.stats[id] = { ["value"] = val, ["name"] = name, }
end

function Stats:get(id)
	return self.stats[id].value
end

function Stats:set(id, val)
	if self.stats[id] == nil then
		self:register(id, val, "generated"..tostring(id))
	else
		self.stats[id].value = val
	end
end

function Stats:add(id, val)
	self.stats[id].value = self.stats[id].value + val
	return self.stats[id].value
end

function Stats:dec(id)
	return self:add(id, -1)
end

function Stats:inc(id)
	return self:add(id, 1)
end

function Stats:tostring(fmtstr, idfilter)
	assert(fmtstr ~= nil and type(fmtstr) == "string",
		"value error: fmtstr must be defined")
	local filter = idfilter or self.stats
	local str = ""

	for k,v in pairs(self.stats) do
		if filter[k] ~= nil then
			str = str..string.format(fmtstr, v.name, v.value)
		end
	end
	return str
end

function Stats:getStats(idfilter)
	local filter = idfilter or self.stats
	local tbl = {}

	for k, v in pairs(self.stats) do
		if filter[k] ~= nil then
			tbl[v.name] = v.value
		end
	end
	return tbl
end

function Stats:marshal()
	return self.stats
end

function Stats:unmarshal(tbl)
	self.stats = tbl
end

return Stats
