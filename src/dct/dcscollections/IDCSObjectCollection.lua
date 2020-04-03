--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a collection of DCS objects or not. Provides
-- an interface to interact with this collection.
--]]

local class = require("libs.class")
local utils = require("libs.utils")
local Goal  = require("dct.Goal")

--[[
IDCSObjectCollection:
	methods(public):
	- __init(template, region)
	- spawn()
		- spawn the DCS objects
	- isSpawned()
		- have the DCS objects been spawned?
	- destroy()
	- isDead()
		- has the asset meet its deathgoal?
	- setDead(val)
		- sets if the object should be thought of as dead or not
	- checkDead()
		- check the asset death goals
	- onDCSEvent(event)
		- process a DCS event associated w/ this asset
	- getStatus()
		- get the "status" of the asset, that being a percentage
		  completion of the death goal
	- getObjectNames()
		- get DCS object names associated with this asset
	- getLocation()
		- get the centroid location of the asset
	- marshal()
	- unmarshal(data)
--]]

local IDCSObjectCollection = class()
function IDCSObjectCollection:__init(asset, template, region)
	assert(asset ~= nil and type(asset) == "table",
		"value error: asset must be provided")
	self._asset = asset
	self._initcomplete  = false
	if template ~= nil and region ~= nil then
		self:_completeinit(template, region)
		self:_setup()
		self._initcomplete  = true
	end
end

function IDCSObjectCollection:_completeinit(_ --[[template]],
	_ --[[region]])
end

function IDCSObjectCollection:_setup()
end

function IDCSObjectCollection:spawn(_ --[[ignore]])
end

function IDCSObjectCollection:isSpawned()
	return true
end

function IDCSObjectCollection:destroy()
end

function IDCSObjectCollection:isDead()
	return false
end

function IDCSObjectCollection:setDead(_ --[[val]])
end

function IDCSObjectCollection:checkDead()
end

function IDCSObjectCollection:onDCSEvent(_ --[[event]])
end

function IDCSObjectCollection:getStatus()
	return 0
end

function IDCSObjectCollection:getObjectNames()
	return {}
end

function IDCSObjectCollection:getLocation()
	return nil
end

function IDCSObjectCollection:marshal()
	assert(self._initcomplete == true,
		"runtime error: init not complete")
	local tbl = {}
	for _, attribute in pairs(self._marshalnames or {}) do
		tbl[attribute] = self[attribute]
	end
	return tbl
end

function IDCSObjectCollection:unmarshal(data)
	assert(self._initcomplete == false,
		"runtime error: init completed already")
	utils.mergetables(self, data)
	self:_setup()
	self._initcomplete = true
	if self:isSpawned() then
		self:spawn(true)
	end
end

function IDCSObjectCollection.defaultgoal(static)
	local goal = {}
	goal.priority = Goal.priority.PRIMARY
	goal.goaltype = Goal.goaltype.DAMAGE
	goal.objtype  = Goal.objtype.GROUP
	goal.value    = 90

	if static then
		goal.objtype = Goal.objtype.STATIC
	end
	return goal
end

return IDCSObjectCollection
