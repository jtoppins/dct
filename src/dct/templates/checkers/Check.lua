--- SPDX-License-Identifier: LGPL-3.0

local class = require("libs.namedclass")
local Logger = dct.Logger.getByName("Template")

local rc = {
	["REQUIRED"] = 1,
	["VALUE"]    = 2,
}

local texttbl = {
	[rc.REQUIRED] = "option not defined but required",
	[rc.VALUE] = "illegal option value",
}

local valuetype = {
	["VALUES"] = 1,
	["INT"]    = 2,
	["RANGE"]  = 3,
	["STRING"] = 4,
	["BOOL"]   = 5,
	["TABLEKEYS"] = 6,
	["TABLE"]  = 7,
}

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

local function check_int(data, key)
	local val

	if type(data[key]) ~= "number" then
		val = tonumber(data[key])
	else
		val = data[key]
	end
	return true, val
end

local function check_range(--[[data, key, values]])
	-- TODO: write this
	return false
end

local function check_string(data, key)
	if type(data[key]) == "string" then
		return true, data[key]
	end
	return false
end

local function check_bool(data, key)
	if type(data[key]) == "boolean" then
		return true, data[key]
	end

	return false
end

local function check_table_keys(data, key, values)
	local val = values[string.upper(data[key])]
	if val ~= nil then
		return true, val
	end
	return false
end

local function check_table(data, key)
	if type(data[key]) == "table" then
		return true, data[key]
	end

	return false
end

local checktbl = {
	[valuetype.VALUES] = check_values,
	[valuetype.INT]    = check_int,
	[valuetype.RANGE]  = check_range,
	[valuetype.STRING] = check_string,
	[valuetype.BOOL]   = check_bool,
	[valuetype.TABLEKEYS] = check_table_keys,
	[valuetype.TABLE]  = check_table,
}

local Check = class("Check")
function Check:__init(section, options, description)
	options = options or {}

	for key, val in pairs(options) do
		if not val.nodoc and val.description == nil then
			Logger:warn("%s.%s is missing a description entry. "..
				"To suppress this add a 'nodoc = true' "..
				"entry in the definition.", section, key)
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
			data[key] = option.default
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
