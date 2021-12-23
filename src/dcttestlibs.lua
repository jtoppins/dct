--[[
-- SPDX-License-Identifier: LGPL-3.0
--]]

local utils = require("libs.utils")
_G.DCT_TEST = true

local airbase_table = {
	["Caucasus"] = {
		[12] = "Anapa-Vityazevo",
		[13] = "Krasnodar-Center",
		[14] = "Novorossiysk",
		[15] = "Krymsk",
		[16] = "Maykop-Khanskaya",
		[17] = "Gelendzhik" ,
		[18] = "Sochi-Adler",
		[19] = "Krasnodar-Pashkovsky",
		[20] = "Sukhumi-Babushara",
		[21] = "Gudauta",
		[22] = "Batumi",
		[23] = "Senaki-Kolkhi",
		[24] = "Kobuleti",
		[25] = "Kutaisi",
		[26] = "Mineralnye Vody",
		[27] = "Nalchik",
		[28] = "Mozdok",
		[29] = "Tbilisi-Lochini",
		[30] = "Soganlug",
		[31] = "Vaziani",
		[32] = "Beslan",
	},
	["PersianGulf"] = {
		[1] = "Abu Musa Island",
		[2] = "Bandar Abbas Intl",
		[3] = "Bandar Lengeh",
		[4] = "Al Dhafra AFB",
		[5] = "Dubai Intl",
		[6] = "Al Maktoum Intl",
		[7] = "Fujairah Intl",
		[8] = "Tumb Island AFB",
		[9] = "Havadarya",
		[10] = "Khasab",
		[11] = "Lar",
		[12] = "Al Minhad AFB",
		[13] = "Qeshm Island",
		[14] = "Sharjah Intl",
		[15] = "Sirri Islan",
		[16] = "Tumb Kochak",
		[17] = "Sir Abu Nuayr",
		[18] = "Kerman",
		[19] = "Shiraz Intl",
		[20] = "Sas Al Nakheel Airport",
		[21] = "Bandar-e-Jask",
		[22] = "Abu Dhabi Intl",
		[23] = "Al-Bateen",
		[24] = "Kish Island Intl",
		[25] = "Al Ain Intl",
		[26] = "Lavan Island",
		[27] = "Jiroft",
		[28] = "Ras Al Khaimah Intl",
		[29] = "Liwa AFB",
	},
}

require("dcttestlibs.dcsstubs")
local warehouses = utils.readlua(lfs.tempdir()..utils.sep.."warehouses",
	"warehouses")
-- create all map airbases
for abid, name in pairs(airbase_table[env.mission.theatre] or {}) do
	local newab = {}
	newab.name = name
	newab.id = abid
	newab.exists = true
	local wairport = warehouses.airports[abid]
	if wairport then
		newab.coalition = coalition.side[wairport.coalition]
		Airbase(newab)
	end
end

local function processCategory(tbl, coa)
	if tbl == nil or tbl.group == nil then
		return
	end
	for _, grp in ipairs(tbl.group) do
		if grp.units then
			for _, unit in ipairs(grp.units) do
				local newab = {
					["name"]   = env.getValueDictByKey(unit.name),
					["id"]     = unit.unitId,
					["exists"] = true,
					["coalition"] = coalition.side[string.upper(coa)],
				}
				Airbase(newab)
			end
		end
	end
end

local catmap = {
	"ship",
}
-- create all mission placed airbases; ships & farps
for coa, coatbl in pairs(env.mission.coalition) do
	for _, cntrytbl in ipairs(coatbl.country) do
		for _, cat in pairs(catmap) do
			processCategory(cntrytbl[cat], coa)
		end
	end
end
