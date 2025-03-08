#!/bin/env lua

require("os")
require("io")
require("lfs")
local DIRSEP = package.config:sub(1,1)
local loglevel

local function log(lvl, msg)
	if loglevel >= lvl then
		print(msg)
	end
end

local function iterator(state)
	state.pos = state.pos + 1
	local key = state.sortedkeys[state.pos]
	local v = state.tbl[key]
	if v ~= nil then
		return key, v
	end
end

local function sortedpairs(t, cmpfn)
	local state = {
		pos = 0,
		tbl = t,
		sortedkeys = {},
	}
	for k in pairs(t) do
		table.insert(state.sortedkeys, k)
	end
	log(2, "unsorted keys #: "..tostring(#state.sortedkeys))
	table.sort(state.sortedkeys, cmpfn)
	log(2, "sorted keys #: "..tostring(#state.sortedkeys))
	log(2, "keys: "..table.concat(state.sortedkeys, ", "))
	return iterator, state
end

local function basicSerialize(s)
	s = s or ""

	if type(s) == 'string' then
		return string.format('%q', s)
	end
	return tostring(s)
end

local function cmp_case_insensitive(a, b)
	if type(a) == "string" or type(b) == "string" then
		return string.lower(tostring(a)) < string.lower(tostring(b))
	end
	return a < b
end

local function serialize(n, vlu, l)
	--Based on ED's serialize_simple2
	local serialize_to_t = function(name, value, level)
		local var_str_tbl = {}
		if level == nil then
			level = ""
		end
		if level ~= "" then
			level = level .. "  "
		end

		table.insert(var_str_tbl, level..name.." = ")

		if type(value) == "number" or
			type(value) == "string" or
			type(value) == "boolean" then
			table.insert(var_str_tbl, basicSerialize(value)..",\n")
		elseif type(value) == "table" then
			table.insert(var_str_tbl, "{\n")
			for k, v in sortedpairs(value, cmp_case_insensitive) do
				local key
				if type(k) == "number" then
					key = string.format("[%s]", k)
				else
					key = string.format("[%q]", k)
				end

				table.insert(var_str_tbl, serialize(key, v, level.."  "))
			end
			if level == "" then
				table.insert(var_str_tbl, level.."} -- end of "..name.."\n")
			else
				table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")
			end
		else
			log(0, "Cannot serialize a " .. type(value))
		end
		return var_str_tbl
	end

	return table.concat(serialize_to_t(n, vlu, l))
end

local function readlua(file, tblname, env)
	assert(file and type(file) == "string", "file path must be provided")
	local f = assert(loadfile(file))
	local config = env or {}
	setfenv(f, config)
	assert(pcall(f))
	local tbl = config
	if tblname ~= nil then
		tbl = config[tblname]
	end
	return tbl
end

local function writelua(path, tblname, tbl, serializer)
	if type(serializer) ~= "function" then
		serializer = function(name, t) return name.." = "..
			tostring(t) end
	end
	local file, e = io.open(path, "w+");
	if not file then
		log(1, string.format("Error while writing mission to file [%s]",
			path))
		return error(e);
	end
	file:write(serializer(tblname, tbl))
	file:close();
end

local function search_table(t, token, usedkeys)
	for _, value in pairs(t) do
		if type(value) == "table" then
			search_table(value, token, usedkeys)
		elseif type(value) == "string" then
			if value:lower():sub(1, #token) == token:lower() then
				usedkeys[value:lower()] = value
			end
		end
	end
end

local used_dictkeys = {}
local dictkey_token = "DictKey_"
local function find_dictkeys(tbl)
	search_table(tbl, dictkey_token, used_dictkeys)
	return tbl
end

local function remove_dictkeys(tbl)
	local result = {}
	local skipped = 0
	for key, value in pairs(tbl) do
		if used_dictkeys[key:lower()] then
			result[key] = value
		else
			log(2, string.format(
				"removing unused dictionary key [%s]=%s",
				key, tostring(value)))
			skipped = skipped + 1
		end
	end
	if skipped > 0 then
		log(1, string.format("removed %d unused keys from dictionary",
			skipped))
	end
	return result
end

local function normalize(output)
	local files = {
		{
			file = "mission",
			proc = find_dictkeys,
			tblname = "mission",
		}, {
			file = "warehouses",
			tblname = "warehouses",
		}, {
			file = "options",
			remove = true,
		}, {
			file = table.concat({"l10n","DEFAULT","dictionary"}, DIRSEP),
			proc = remove_dictkeys,
			tblname = "dictionary",
		}, {
			file = table.concat({"l10n","DEFAULT","mapResource"}, DIRSEP),
			tblname = "mapResource",
		},
	}

	for _, mizfile in ipairs(files) do
		local path = mizfile.file
		if output then
			path = output..DIRSEP..path
		end

		log(1, "processing: "..path)
		if mizfile.remove then
			if lfs.attributes(path) ~= nil then
				os.remove(path)
			end
		else
			local tbl = readlua(path, mizfile.tblname)
			if type(mizfile.proc) == "function" then
				tbl = mizfile.proc(tbl, mizfile)
			end
			writelua(path, mizfile.tblname, tbl, serialize)
		end
	end
end

local function unzip(miz, output)
	local unzip_options = "-o"
	if loglevel < 1 then
		unzip_options = unzip_options.."q"
	end
	local cmd = "unzip "..unzip_options.." \""..miz.."\""
	if output ~= nil then
		cmd = cmd.." -d \""..output.."\""
	end
	return os.execute(cmd)
end

local parser = require("argparse")("normalize",
	[[Normalize DCS mission files so they can be easily version controlled.]])
parser:argument("miz", "Mission file")
parser:option("-o --output", "Output path")
	:target("output")
	:argname("<path>")
parser:flag("-v --verbose", "Increase verbosity level")
	:count("0-2")
	:target("loglevel")

local args = parser:parse()
loglevel = args.loglevel
assert(unzip(args.miz, args.output) == 0)
normalize(args.output)
return 0
