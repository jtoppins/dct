-- SPDX-License-Identifier: LGPL-3.0

--- Handles loading a file and extracting the specified filenames and
-- converting them to lua tables.
-- @module dct.templates.zip

local ziptype = {
	["MINIZIP"] = 1,
	["LUAZIP"]  = 2,
}

local ztype = ziptype.MINIZIP
local ok, zip = pcall(require, "minizip")
if not ok then
	ztype = ziptype.LUAZIP
	ok, zip = pcall(require, "luazip")
	assert(ok, "unable to load zip library")
end

--- Extract all files using minizip, exit on first error.
local function minizip_extract(z, ...)
	local tbl = {}

	for _, filename in ipairs(arg) do
		local result

		local str = z:extract(filename)
		local f, err = loadstring(str)
		if not f then
			return nil, err
		end

		setfenv(f, tbl)
		result, err = pcall(f)
		if not result then
			return nil, err
		end
	end

	return tbl
end

--- Extract all files using luazip, exit on first error.
local function luazip_extract(z, ...)
	local tbl = {}

	for _, filename in ipairs(arg) do
		local file, f, result, err

		file, err = z:open(filename)
		if not file then
			return nil, err
		end

		local str = file:read("*a")
		file:close()
		f, err = loadstring(str)
		if not f then
			return nil, err
		end

		setfenv(f, tbl)
		result, err = pcall(f)
		if not result then
			return nil, err
		end
	end

	return tbl
end

--- Extract the specified files from the zip archive and convert them
-- to a lua table.
-- @treturn table merged table
local function extract(zippath, ...)
	local z, errmsg = zip.open(zippath)
	local tbl, err

	if not z then
		return nil, errmsg
	end

	if ziptype.MINIZIP == ztype then
		tbl, err = minizip_extract(z, ...)
	elseif ziptype.LUAZIP == ztype then
		tbl, err = luazip_extract(z, ...)
	end
	z:close()

	return tbl, err
end

return extract
