-- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local utils    = require("libs.utils")
local json     = require("libs.json")
local graph    = require("libs.container.graph")
local vector   = require("dct.libs.vector")
local Marshallable = require("dct.libs.Marshallable")
local Logger   = require("dct.libs.Logger").getByName("Terrain")
local dcsterrain = require("Terrain")

-- TODO: issues
-- The world has land which is below sea-level so simply storing a
-- negative height to represent seas is not possible.
--
-- Solution: each node will need to store a surface type, which
--    is the surface type of the majority of the samples taken
--    in the cell. Then the neighbors method returns cells of
--    similar surface type.
--
-- Cost calculations:
--   Finding lowest terrain to goal:
--     the cost is the distance from previous to current plus
--     terrain height
--   Finding navigable waterway to goal:
--     the cost is the distance from previous to current but the
--     neighbor method needs to filter nodes that are not a surface
--     type of water and have a minimum depth of X
--
-- Problem: Find a path to goal through lowest terrain avoiding
--    obstacles(sam sites)
--
-- given all these different criteria to search a graph, it would be
-- best to provide the neighbors() function as an input to the
-- search algorithm.

local CACHEPATH = utils.join_paths(lfs.writedir(), "DCT", "cache",
				   env.mission.theatre.."_heightmap.json")
local surface_type_map = {
	[land.SurfaceType.LAND]          = land.SurfaceType.LAND,
	[land.SurfaceType.SHALLOW_WATER] = land.SurfaceType.WATER,
	[land.SurfaceType.WATER]         = land.SurfaceType.WATER,
	[land.SurfaceType.ROAD]          = land.SurfaceType.LAND,
	[land.SurfaceType.RUNWAY]        = land.SurfaceType.LAND,
}

--- Calculate cell height by taking height samples over the cell
-- and take the maximum height sampled.
-- @param sw_corner corner of the cell
-- @param cellsize the size of the cell
-- @return maximum height found in the cell and the most prevalent
-- surface type found
local function cell_height(sw_corner, cellsize)
	local maxheight = 0
	local mindepth = 500000
	local slices = 3
	local u = cellsize / slices
	local surface = land.SurfaceType.LAND
	local sfctype = {
		[land.SurfaceType.LAND]  = 0,
		[land.SurfaceType.WATER] = 0,
	}

	-- TODO: this is slightly inefficient in that about 24 points
	-- will be sampled twice per inner cell in the overall map
	local x = sw_corner.x
	for _ = 0, slices do
		local y = sw_corner.y
		for _ = 0, slices do
			local sample_pt = { ["x"] = x, ["y"] = y, }
			local stype = surface_type_map[
					land.getSurfaceType(sample_pt)]
			local height, depth =
				land.getSurfaceHeightWithSeabed(sample_pt)

			sfctype[stype] = sfctype[stype] + 1
			maxheight = math.max(maxheight, height)
			mindepth = math.min(mindepth, depth)
			y = y + u
		end
		x = x + u
	end

	if sfctype[land.SurfaceType.LAND] < sfctype[land.SurfaceType.WATER] then
		surface = land.SurfaceType.WATER
	end

	if surface == land.SurfaceType.WATER then
		return mindepth, surface
	end
	return maxheight, surface
end

--- Terrain cell in the height map graph.
-- @class TerrainNode : libs.container.graph.Node
local TerrainNode = class("TerrainNode", graph.Node, Marshallable)
function TerrainNode:__init(id, height, surfacetype)
	Marshallable.__init(self)
	self.id = id
	self._h = height
	self._sfctype = surfacetype
	self._refnum = 1

	self:_addMarshalNames({"_h", "_sfctype", "_refnum",})
end

--- increment internal reference counter
function TerrainNode:incRef()
	self._refnum = self._refnum + 1
end

--- decrement internal reference counter
function TerrainNode:decRef()
	self._refnum = self._refnum - 1
end

--- return height of node and surface type
function TerrainNode:height()
	return self._h, self._sfctype
end


--- Initialize terrain graph for the Theater.
-- @class Terrain : libs.container.graph.Graph
local Terrain = class("Terrain", graph.Graph)
function Terrain:__init()
	graph.Graph.__init(self)

	self.cellsize = 500
	if self:cacheExists() then
		self:load()
	else
		self:build()
	end

	-- remove unsupported methods
	self.exists = nil
	self.add_node = nil
	self.remove_node = nil
	self.add_edge = nil
	self.remove_edge = nil
end

function Terrain:cacheExists()
	local attr = lfs.attributes(CACHEPATH)
	return attr ~= nil and attr.mode == "file"
end

function Terrain:nodeID(row, col)
	return (row * self.cols) + col + 1
end

function Terrain:load()
	local file = assert(io.open(CACHEPATH))
	local tbl = json:decode(file:read("*all"))

	file:close()
	self.cellsize = tbl.cellsize
	self.origin = vector.Vector2D(tbl.origin)
	self.rows = tbl.rows
	self.cols = tbl.cols
	self.nodes[1] = tbl.nodes[tostring(1)]

	local i = 2
	local cnt = self.rows * self.cols
	while i <= cnt do
		if tbl.nodes[tostring(i)] == nil then
			self.nodes[i] = tbl.nodes[tostring(i-1)]
		else
			self.nodes[i] = tbl.nodes[tostring(i)]
		end
		i = i + 1
	end
end

function Terrain:writecache()
	local tbl = {}
	tbl.cellsize = self.cellsize
	tbl.origin = self.origin:raw()
	tbl.rows = self.rows
	tbl.cols = self.cols
	tbl.nodes = {}
	tbl.nodes[1] = self.nodes[1]

	local cnt = tbl.rows * tbl.cols
	local i = 2
	while i <= cnt do
		if self.nodes[i]._refnum > 1 then
			tbl.nodes[i] = self.nodes[i]
			i = i + self.nodes[i]._refnum
		else
			tbl.nodes[i] = self.nodes[i]
			i = i + 1
		end
	end

	local file = assert(io.open(CACHEPATH))
	file:write(json:encode(tbl))
	file:close()
end

--- Determine if the current cell's height is within 10 meters of the
-- previous cell's height.
function Terrain:_summarize(id, height, surface)
	local prevcell = self.nodes[id-1]
	local pheight, psurface = prevcell:height()

	if psurface == surface then
		if math.abs(height - pheight) < 10 then
			prevcell:incRef()
			self.nodes[id] = prevcell
		else
			self.nodes[id] = TerrainNode(id, height, surface)
		end
	else
		self.nodes[id] = TerrainNode(id, height, surface)
	end
end

function Terrain:build()
	local SW_bound = dcsterrain.GetTerrainConfig("SW_bound")
	local NE_bound = dcsterrain.GetTerrainConfig("NE_bound")
	local ne = vector.Vector2D.create(NE_bound[1] * 1000,
					  NE_bound[3] * 1000)

	self.origin = vector.Vector2D.create(SW_bound[1] * 1000,
					     SW_bound[3] * 1000)
	local dimentions = ne - self.origin
	self.rows = math.ceil(dimentions.x / self.cellsize)
	self.cols = math.ceil(dimentions.y / self.cellsize)

	local x = self.origin.x
	for row = 0, self.rows - 1 do
		local y = self.origin.y

		for col = 0, self.cols - 1 do
			local id = self:nodeID(row, col)
			local corner = vector.Vector2D.create(x, y)
			local height, sfctype = cell_height(corner,
							    self.cellsize)

			-- TODO: could be optimized a little here by creating
			-- the first node above the inner for loop and then just
			-- call summarize directly.
			if col > 0 then
				self:_summarize(id, height, sfctype)
			else
				self.nodes[id] = TerrainNode(id, height,
							     sfctype)
			end
			y = y + self.cellsize
		end
		x = x + self.cellsize
	end
	self:writecache()
end

--- Return node, edge pairs that are neighbors to this node.
function Terrain:neighbors(node)
end

--- Determines if two nodes are connected (adjacent).
function Terrain:adjacent(node1, node2)
end

--- Find the node object that contains point
function Terrain:node(point)
	local v = vector.Vector2D(point)
	local x = math.floor(v.x / self.cellsize)
	local y = math.floor(v.y / self.cellsize)

	return self.nodes[self:nodeID(x, y)]
end

function Terrain:getPoint(node)
	local u = self.cellsize / 2
	local row = math.floor((node.id - 1) / self.rows)
	local col = (node.id - 1) - (row * self.cols)
	local x = (row * self.cellsize) + u
	local y = (col * self.cellsize) + u

	return self.origin + { ["x"] = x, ["y"] = y, }
end

return Terrain
