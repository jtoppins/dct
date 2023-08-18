--- SPDX-License-Identifier: LGPL-3.0

local class = require("libs.namedclass")
local utils = require("libs.utils")
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
}

local Check = class("Check")
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
end

Check.rc = rc
Check.reasontext = texttbl
Check.valuetype = valuetype

--- checks the if the options in data have legal values
--
-- @param data the table of options to check
-- @return bool, true if all options are legal
--   if an option is invalid the function will return a 3 tuple
--   false, option_name, reason
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

--- Documentation generation
--
-- @return a table documenting the options
-- format: {
--    ["section"] = "section name",
--    ["options"] = {
--          ["option name"] = {
--                  ["default"] optional default value
--                  ["description"] option description
--                  ["type"] type of values table
--                  ["values"] table describing the possible values
--                             the option can have
function Check:doc()
	local d = {
		["section"] = self.section,
		["description"] = self.description,
		["options"] = self.options,
	}

	return d
end

return Check
