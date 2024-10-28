-- SPDX-License-Identifier: LGPL-3.0

require("libs")

local class    = libs.classnamed
local dctutils = require("dct.libs.utils")

--- Memory interface. Provides a common API for interacting with an object
-- that has memory and attempts to remember facts.
-- @classmod dct.libs.Memory
local Memory = class("Memory")

--- Constructor.
function Memory:__init()
	self.memory = {}
end

--- Looks for a fact in memory.
--
-- @param test a test function of the form, `bool test(key, fact)`,
--   where a true result means the fact we are looking for exists in
--   the table
-- @return true, key or false
function Memory:hasFact(test)
	for key, fact in pairs(self.memory) do
		if test(key, fact) then
			return true, key
		end
	end
	return false
end

--- Get a known fact from memory.
--
-- @param key [any] get the fact indexed by key
-- @return [table] return the fact
function Memory:getFact(key)
	return self.memory[key]
end

--- Add or overwrite a fact in the Agent's memory.
--
-- @param key [any] value, if nil a key is generated
-- @param fact [table] the fact object to store
-- @return [any] the key where the fact was stored
function Memory:setFact(key, fact)
	local incctr = false

	if key == nil then
		incctr = true
		key = self._factcntr
	end
	self.memory[key] = fact

	if incctr then
		self._factcntr = self._factcntr + 1
	end
	return key
end

--- Deletes all facts where test returns true.
--
-- @param test a test function of the form, `bool test(key, fact)`,
--   where a true result causes the fact to be deleted
-- @return table of deleted facts
function Memory:deleteFacts(test)
	local deletedfacts = {}
	for key, fact in pairs(self.memory) do
		if test(key, fact) then
			self.memory[key] = nil
			deletedfacts[key] = fact
		end
	end
	return deletedfacts
end

--- Delete all facts in memory.
function Memory:deleteAllFacts()
	self.memory = {}
end

--- Iterate over facts in memory.
--
-- @param filter a function of the form, `bool func(obj)`, used to filter
--   facts returned by the iterator, filter must return true to include
--   the fact in the iteration.
-- @return an iterator to be used in a for loop
function Memory:iterateFacts(filter)
	filter = filter or dctutils.no_filter
	local function fnext(state, index)
		local idx = index
		local fact
		repeat
			idx, fact = next(state, idx)
			if fact == nil then
				return nil
			end
		until(filter(fact))
		return idx, fact
	end
	return fnext, self.memory, nil
end

return Memory
