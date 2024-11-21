--- SPDX-License-Identifier: LGPL-3.0
--
-- Creates a container for managing region objects.

require("libs")
local class        = libs.classnamed
local utils        = libs.utils
local vector       = require("dct.libs.vector")
local Marshallable = require("dct.libs.Marshallable")
local Region       = require("dct.templates.Region")
local settings = dct.settings.server

--- RegionManager
-- Keeps a collection of Region classes and allows for easy lookup
-- of a Region within the collection.
--
-- @field regions holds the table of regions indexed by Region.name
local RegionManager = class("RegionManager",
	Marshallable)
function RegionManager:__init(theater)
	self.regions = {}

	self:loadRegions()
	theater:getAssetMgr():addObserver(self.onDCTEvent, self,
		self.__clsname..".onDCTEvent")
end

function RegionManager:getRegion(name)
	return self.regions[name]
end

function RegionManager:addRegion(region)
	self.regions[region.name] = region
end

function RegionManager:iterate()
	return next, self.regions, nil
end

--- Loads all regions defined in the theater.
function RegionManager:loadRegions()
	for filename in lfs.dir(settings.theaterpath) do
		if filename ~= "." and filename ~= ".." and
		   filename ~= ".git" and filename ~= "settings" then
			local fpath = settings.theaterpath..utils.sep..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region.fromFile(fpath)
				assert(self.regions[r.name] == nil,
				       "duplicate regions defined for "..
				       "theater: " .. settings.theaterpath)
				self.regions[r.name] = r
			end
		end
	end
end

local function cost(thisrgn, otherrgn)
	if thisrgn == nil or otherrgn == nil then
		return nil
	end
	return vector.distance(vector.Vector2D(thisrgn:getPoint()),
		vector.Vector2D(otherrgn:getPoint()))
end

function RegionManager:validateEdges()
	for _, thisrgn in pairs(self.regions) do
		local links = {}
		for domain, lnks in pairs(thisrgn.links) do
			links[domain] = {}
			for _, rgnname in pairs(lnks) do
				if rgnname ~= thisrgn.name then
					links[domain][rgnname] =
						cost(thisrgn, self.regions[rgnname])
				end
			end
		end
		thisrgn.links = links
	end
end

function RegionManager:generate()
	for _, r in pairs(self.regions) do
		r:generate()
	end
	self:validateEdges()
end

-- TODO: with the new approach to referencing templates I am not sure Regions
-- need to store any data.
function RegionManager:marshal()
	local tbl = {}
	tbl.regions = {}

	for rgnname, region in pairs(self.regions) do
		tbl.regions[rgnname] = region:marshal()
	end
	return tbl
end

function RegionManager:unmarshal(data)
	if data.regions == nil then
		return
	end
	for rgnname, region in pairs(self.regions) do
		region:unmarshal(data.regions[rgnname])
	end
end

local relevants = {
	[dct.event.ID.DCT_EVENT_DEAD]      = true,
	[dct.event.ID.DCT_EVENT_ADD_ASSET] = true,
}

function RegionManager:onDCTEvent(event)
	if relevants[event.id] == nil then
		return
	end

	local region = self.regions[event.initiator.rgnname]
	if region then
		region:onDCTEvent(event)
	end
end

return RegionManager
