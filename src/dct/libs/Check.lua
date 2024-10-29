-- SPDX-License-Identifier: LGPL-3.0

--- Check class.
-- Used to check a table against a set of required/optional fields
-- that need to be set in the table and verifies the fields values
-- conform to a specific type.
-- @module dct.libs.Check

local class = require("libs.classnamed")
local utils = require("libs.utils")
local dctutils = require("dct.libs.utils")
local vector = require("dct.libs.vector")

local rc = {
	["REQUIRED"] = 1,
	["VALUE"]    = 2,
}

local texttbl = {
	[rc.REQUIRED] = "option not defined but required",
	[rc.VALUE] = "illegal option value",
}

local valuetype = {
	["VALUES"]    = 1, -- enumerated list of allowed values
	["INT"]       = 2, -- number
	["RANGE"]     = 3, -- number range
	["STRING"]    = 4, -- string
	["BOOL"]      = 5, -- boolean
	["TABLEKEYS"] = 6, -- enumerated list of allowed values as keys
                           --   from supplied table
	["TABLE"]     = 7, -- simple lua table
	["POINT"]     = 8, -- is a point
	["LISTKEYS"]  = 9, -- is a list of table keys
	["LIST"]      = 10, -- a list where all values are of the
			    --  specified type
	["UINT"]      = 11, -- unsigned number
}

--- Used when the item being checked has a single value but from
-- an enumerated list of values where the data input for key
-- is used to get the value. Similar to TABLEKEYS except here
-- the actual value is stored in value and there is a description
-- string that can accompany each value.
local function check_values(data, key, values)
	local val = values[string.upper(data[key])]
	if type(val) == "table" then
		val = val.value
	end
	if val == nil then
		return false
	end
	return true, val
end

--- checks that the value is a number
local function check_int(data, key)
	local val
	if type(data[key]) ~= "number" then
		val = tonumber(data[key])
	else
		val = data[key]
	end
	return true, val
end

--- checks that the value is within a range where the values
-- table defines a min and max.
local function check_range(data, key, values)
	local val = tonumber(data[key])
	if values[1] <= val and data[key] <= val then
		return true, val
	end
	return false
end

--- verifies the value is a string
local function check_string(data, key)
	if type(data[key]) == "string" then
		return true, data[key]
	end
	return false
end

--- verifies the value is a boolean
local function check_bool(data, key)
	if type(data[key]) == "boolean" then
		return true, data[key]
	end
	return false
end

--- Used when the item being checked has a single value but from
-- an enumerated list of values defined as keys in a table where
-- the value of each key will be what the item gets transformed to.
-- Verifies the value of data[key] exists as an uppercase key
-- in values. The value returned is the value from the key accessed
-- in the values table.
local function check_table_keys(data, key, values)
	local val = values[string.upper(data[key])]
	if val ~= nil then
		return true, val
	end
	return false
end

--- verifies the value refrenced in data by key (data[key])
-- is a table. This should not be used often.
local function check_table(data, key)
	if type(data[key]) == "table" then
		return true, data[key]
	end
	return false
end

--- verify the value is a point or return a point at the map
-- origin.
local function check_point(data, key)
	local val = vector.Vector3D(data[key])
	return true, val:raw()
end

--- verify all items in the list are keys in values and translate
-- to a set.
local function check_list_keys(data, key, values)
        local newlist = {}
        for _, v in ipairs(data[key]) do
                local val = string.upper(v)
                if type(v) ~= "string" or values[val] == nil then
                        return false
                end
                newlist[values[val]] = true
        end
        return true, newlist
end

--- verify all items in the list are of a specific type.
local function check_list(data, key, values)
        for _, val in ipairs(data[key]) do
                if type(val) ~= values then
                        return false
                end
        end
        return true, data[key]
end

--- verify the value is an unsigned number
local function check_uint(data, key)
	local ok, val = check_int(data, key)

	if not ok or val < 0 then
		return false
	end
	return true, val
end

local checktbl = {
	[valuetype.VALUES] = check_values,
	[valuetype.INT]    = check_int,
	[valuetype.RANGE]  = check_range,
	[valuetype.STRING] = check_string,
	[valuetype.BOOL]   = check_bool,
	[valuetype.TABLEKEYS] = check_table_keys,
	[valuetype.TABLE]  = check_table,
	[valuetype.POINT]  = check_point,
	[valuetype.LISTKEYS] = check_list_keys,
	[valuetype.LIST]   = check_list,
	[valuetype.UINT]   = check_uint,
}

local value_header = {
	[valuetype.VALUES]    = "specific values",
	[valuetype.INT]       = "number",
	[valuetype.RANGE]     = "range",
	[valuetype.STRING]    = "string",
	[valuetype.BOOL]      = "boolean (true/false)",
	[valuetype.TABLEKEYS] = "specific values",
	[valuetype.TABLE]     = "table",
	[valuetype.UINT]      = "positive number",
}

local function is_required(option)
	local s = " - _required:_ "

	if option.default ~= nil then
		s = s.."no"

		if option.default ~= "" and
		   type(option.default) ~= "table" and
		   option.type ~= valuetype.VALUES then
			s = s.."\n - _default:_ "..tostring(option.default)
		elseif option.type == valuetype.VALUES then
			local found = nil
			for key, data in pairs(option.values) do
				if data.value == option.default then
					found = key
					break
				end
			end

			if found ~= nil then
				s = s.."\n - _default:_ "..tostring(found)
			end
		end
	else
		s = s.."yes"
	end
	return s
end

local function option_summary(option)
	local summary = is_required(option).."\n"

	summary = summary.." - _value:_ "..value_header[option.type]
	if option.type == valuetype.RANGE then
		summary = summary..string.format(" [%d, %d]",
			option.values[1], option.values[2])
	end
	summary = summary.."\n"
	if option.agent then
		summary = summary.." - _agent:_ true\n"
	end
	if option.deprecated then
		summary = summary.."\n_NOTE: this option has been "..
			  "deprecated._\n"
	end
	return summary
end

local function option_description(option)
	local desc = option.description.."\n"

	if option.type == valuetype.VALUES or
	   option.type == valuetype.TABLEKEYS or
	   (option.type == valuetype.TABLE and
	    option.values ~= nil) then
		local values = ""
		for k, v in utils.sortedpairs(option.values) do
			values = values.." - `"..k.."`"
			if option.type == valuetype.VALUES then
				values = values.." - "..v.description
			end
			values = values.."\n"
		end
		local len = string.len(values)
		values = string.sub(values, 1, len - 1)

		desc = dctutils.interp(desc, {
			["VALUES"] = values,
		})
	end
	return desc
end

local function write_section(level, name, data)
	if next(data.options) == nil then
		return
	end

	print(string.format("\n%s %s\n", string.rep("#", level), name))
	if data.description then
		print(data.description)
	end

	for optname, optdata in utils.sortedpairs(data.options) do
		print(string.format("\n%s `%s`\n",
				    string.rep("#", level+1), optname))
		print(option_summary(optdata))
		print(option_description(optdata))
	end
end

--- Check class.
-- @type Check
local Check = class("Check")

--- Constructor.
-- @string section section header.
-- @tparam table options option table.
-- @string description [optional] summary description.
function Check:__init(section, options, description)
	options = options or {}

	for key, val in pairs(options) do
		if not val.nodoc and val.description == nil then
			dct.Logger.getByName("Template"):warn(
				"%s.%s is missing a description entry. "..
				"To suppress this add a 'nodoc = true' "..
				"entry in the definition.",
				tostring(section), tostring(key))
		end
	end
	self.section = section
	self.description = description
	self.options = options
	self.rc = nil
	self.reasontext = nil
	self.valuetype = nil
end

Check.rc = rc
Check.reasontext = texttbl
Check.valuetype = valuetype

--- class function to generate check documentation.
-- Generate markdown styled documentation for all options checked for by
-- the given set of checkers. Output to standard out.
function Check.genDocs(header, checkers)
	local sections = {}
	for _, c in pairs(checkers) do
		local doc = c:doc()
		if sections[doc.section] == nil and next(doc.options) then
			sections[doc.section] = {}
			sections[doc.section]["options"] = {}
		end

		if doc.description then
			sections[doc.section]["description"] = doc.description
		end

		for key, val in pairs(doc.options) do
			if val.nodoc ~= true then
				sections[doc.section]["options"][key] = val
			end
		end
	end

	print(header)
	for name, data in utils.sortedpairs(sections) do
		write_section(2, name, data)
	end
end

--- checks that if the options in data have legal values.
--
-- @tparam table data the table of options to check
-- @treturn[1] bool true if all options are legal
-- @treturn[2] bool false if an option is invalid
-- @treturn[2] string option name that is in error
-- @treturn[2] string reason string
function Check:check(data)
	for key, option in pairs(self.options) do
		if option.deprecated and data[key] ~= nil then
			dct.Logger.getByName("Template"):warn(
				"%s: option '%s' is deprecated; file: %s",
				tostring(data.name), key,
				tostring(data.filedct))
		end

		if data[key] == nil and option.default == nil then
			return false, key, texttbl[rc.REQUIRED]
		elseif data[key] == nil and option.default ~= nil then
			data[key] = utils.deepcopy(option.default)
		else
			local ok, value =
				checktbl[option.type](data, key, option.values)
			if ok == false then
				return false, key,
				       string.format(texttbl[rc.VALUE]..
						     ": %s", data[key] or "nil")
			end
			data[key] = value
		end
	end
	return true
end

--- Get a list of the options that should be copied from the template
-- and stored in the Agent.
--
-- @return table whos keys are the options that need to be copied
function Check:agentOptions()
	local keys = {}

	for key, val in pairs(self.options) do
		if val.agent then
			keys[key] = true
		end
	end

	return keys
end

--- Documentation generation.
-- Will return a table of the format:
-- ```
-- {
--    ["section"] = "section name",
--    ["options"] = {
--          ["option name"] = {
--                  ["default"] optional default value
--                  ["description"] option description
--                  ["type"] type of values table
--                  ["values"] table describing the possible values
--                             the option can have
-- ```
--
-- @treturn table documenting the options
function Check:doc()
	local d = {
		["section"] = self.section,
		["description"] = self.description,
		["options"] = self.options,
	}

	return d
end

return Check
