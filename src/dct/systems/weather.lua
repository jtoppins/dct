-- SPDX-License-Identifier: LGPL-3.0

--- Weather system. Reads the mission's weather settings and
-- provides some nice methods for getting data about the
-- weather; closest VFR altitude, metar for players, etc.
-- @classmod dct.systems.weather

require("libs")
local class = libs.classnamed
local utils = libs.utils
local uihuman = require("dct.ui.human")

local cloudcoverage = {
	{
		value = 2/8,
		name = "FEW",
	}, {
		value = 4/8,
		name = "SCT",
	}, {
		value =	7/8,
		name = "BKN",
	}, {
		value = 1,
		name = "OVC",
	},
}

local raincoverage = {
	{
		value = 0,
		name = "",
	}, {
		value = 0.25,
		name = "RA-",
	}, {
		value = 0.65,
		name = "RA",
	}, {
		value = 1,
		name = "RA+",
	},
}

local function coverage(x, tbl)
	for _, data in ipairs(tbl) do
		if x <= data.value then
			return data.name
		end
	end
	return ""
end

local function underscore(str)
	return str
end

local function lerpfactor(base, data)
	local n = base - data.presetAltMin
	local d = data.presetAltMax - data.presetAltMin

	return n / d
end

local function lerp(a, b, t)
	return a + ((b - a) * t)
end

local function try_lower_alt(curlayer, prevlayer, min)
	local alt = curlayer.min - 150

	if alt < min then
		return nil
	end

	if prevlayer == nil or (prevlayer.max + 300) < alt then
		return alt
	end

	return nil
end

local function round(num)
	return num + (2^52 + 2^51) - (2^52 + 2^51)
end

local Weather = class("Weather")
function Weather:__init()
	local preset = env.mission.weather.clouds.preset
	local cloudbase = env.mission.weather.clouds.base
	local cloud_presets = utils.readlua(
		utils.join_paths(lfs.currentdir(), "Config",
				 "Effects", "clouds.lua"),
		nil,
		{ ["_"] = underscore, })
	local clouds = cloud_presets.clouds.presets[preset]
	local factor = lerpfactor(cloudbase, clouds)

	self.precip = clouds.precipitationPower
	self.layers = {}
	for k, layer in ipairs(clouds.layers) do
		if layer.coverage > 0 then
			local l = {}
			local thickness = layer.altitudeMax -
						layer.altitudeMin

			l.min = math.floor(lerp(layer.altitudeMin,
						layer.altitudeMax, factor))
			l.max = math.ceil(l.min + thickness)
			l.coverage = layer.coverage

			self.layers[k] = l
		end
	end
end

--- In aviation a ceiling is any cloud layer that is broken or
-- overcast. This is useful for setting believable altitudes for
-- bombing and other AI related things.
--
-- @return base of first layer with a broken+ coverage or nil
--  if sky is clear
function Weather:getCeiling()
	local ceiling

	for _, layer in ipairs(self.layers) do
		if layer.coverage > 0.5 then
			ceiling = layer.min
			break
		end
	end

	return ceiling
end

--- find an altitude outside of a cloud layer and within
-- a given range. If min and max are not provided assume
-- a min and max between 8000ft and 80000ft.
--
-- @param min the minimum altitude allowed
-- @param max the maximum altitude allowed
-- @return a VFR altitude with min & max or zero meaning there
--  does not exist a VFR altitude within the range.
-- luacheck: max_cyclomatic_complexity 13
function Weather:findVFRAltitude(alt, min, max)
	min = min or 2438
	max = max or 24384

	if alt == nil or alt < min then
		alt = min
	end

	for k, layer in ipairs(self.layers) do
		if alt < layer.min then
			-- below layer, already VFR
			local newalt = layer.min - 150
			alt = alt > newalt and newalt or alt
			break
		elseif alt >= layer.min and alt <= layer.max then
			-- inside layer, test if going just below
			-- the layer is within our criteria, if so
			-- stop
			alt = try_lower_alt(layer, self.layers[k-1], min)
			if alt ~= nil then
				break
			end
			alt = layer.max + 300
		end
	end

	if alt > max then
		alt = 0
	end
	return alt
end

--- Construct a METeorological Aerodrome Report (METAR) string for
-- the current weather conditions at the specified point.
-- format: <identifier> <time> <vis> <rain/fog> <cloud layers>
--         <temp/dewpoint> <pressure>
function Weather:metar(point, player)
	local tempfmt = player:getDescKey("tempfmt")
	local altfmt = player:getDescKey("altfmt")
	local pressurefmt = player:getDescKey("pressurefmt")
	local temp, pressure = atmosphere.getTemperatureAndPressure(point)
	local metar = coverage(self.precip, raincoverage)
	local skyclear = true

	if string.len(metar) > 0 then
		metar = metar.." "
	end
	for k, layer in ipairs(self.layers) do
		if layer.coverage > 0 then
			if k > 1 then
				metar = metar.." "
			end

			local base = uihuman.convert(layer.min,
					uihuman.units.ALTITUDE, altfmt)
			metar = metar..string.format("%03d",
				round(base/100))..
				coverage(layer.coverage, cloudcoverage)
			skyclear = false
		end
	end

	if skyclear == true then
		metar = metar.." CLR"
	end

	local t = uihuman.convert(temp, uihuman.units.TEMP, tempfmt)
	local p= uihuman.convert(pressure, uihuman.units.PRESSURE,
				  pressurefmt)
	metar = metar..string.format(" %d/- %.2f", t, p)
	return metar
end

return Weather
