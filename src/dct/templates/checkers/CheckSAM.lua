--- SPDX-License-Identifier: LGPL-3.0

local class    = require("libs.namedclass")
local dctenum  = require("dct.enum")
local Check    = require("dct.templates.checkers.Check")

local adtypes = {
	[dctenum.assetType.BASEDEFENSE] = true,
	[dctenum.assetType.EWR]         = true,
	[dctenum.assetType.SAM]         = true,
	[dctenum.assetType.SHORAD]      = true,
}

local ewr = {
	["threat"] = 1,
	["range"]  = 100000,
	["update"] = 15,
	["attrs"]  = {
		["EWR"] = true,
	},
	["name"]   = "EWR",
}

local sammap = {
	["1L13 EWR"] = ewr,
	["55G6 EWR"] = ewr,
	["FPS-117"] = ewr,
	["SNR_75V"] = {
		["threat"]    = 20,
		["range"]     = 65000,
		["update"]    = 14,
		["name"]      = "SA-2",
	},
	["snr s-125 tr"] = {
		["threat"]    = 30,
		["range"]     = 60000,
		["update"]    = 14,
		["name"]      = "SA-3",
	},
	["RPC_5N62V"] = {
		["threat"]    = 40,
		["range"]     = 120000,
		["update"]    = 15,
		["name"]      = "SA-5",
	},
	["Kub 1S91 str"] = {
		["threat"]    = 31,
		["range"]     = 52000,
		["update"]    = 10,
		["name"]      = "SA-6",
	},
	["Dog Ear radar"] = {
		["threat"]    = 25,
		["range"]     = 25000,
		["update"]    = 10,
		["name"]      = "SA-8",
	},
	["S-300PS 40B6MD sr"] = {
		["threat"]    = 50,
		["range"]     = 100000,
		["update"]    = 8,
		["name"]      = "SA-10",
	},
	["SA-11 Buk SR 9S18M1"] = {
		["threat"]    = 29,
		["range"]     = 43000,
		["update"]    = 6,
		["name"]      = "SA-11",
	},
	["HQ-7_STR_SP"] = {
		["threat"]    = 15,
		["range"]     = 10000,
		["update"]    = 9,
		["name"]      = "HQ-7",
	},
	["Roland Radar"] = {
		["threat"]    = 10,
		["range"]     = 7500,
		["update"]    = 6,
		["name"]      = "Roland",
	},
	["Hawk sr"] = {
		["threat"]    = 30,
		["range"]     = 60000,
		["update"]    = 8,
		["name"]      = "Hawk",
	},
	["Patriot str"] = {
		["threat"]    = 40,
		["range"]     = 100000,
		["update"]    = 7,
		["name"]      = "Patriot",
	},
	["NASAMS_Radar_MPQ64F1"] = {
		["threat"]    = 15,
		["range"]     = 14000,
		["update"]    = 5,
		["name"]      = "NASAMS",
	},
}
sammap["FPS-117 Dome"] = sammap["FPS-117"]

local function classify(data)
	local saminfo = {}

	for typename, _ in pairs(data.unitTypeCnt) do
		local info = sammap[typename]
		local threat = saminfo.threat or 0

		if info ~= nil and info.threat > threat then
			saminfo = info
		end
	end

	if saminfo.threat == nil or saminfo.threat == 0 then
		if data.attributes["LR SAM"] ~= nil then
			saminfo.range = 100000
			saminfo.name  = "LR SAM"
			saminfo.update = 12
		elseif data.attributes["MR SAM"] ~= nil then
			saminfo.range = 60000
			saminfo.name  = "MR SAM"
			saminfo.update = 12
		elseif data.attributes["SR SAM"] ~= nil then
			saminfo.range = 12000
			saminfo.name  = "SR SAM"
			saminfo.update = 12
		else
			saminfo.range = 100000
			saminfo.name  = "EWR"
			saminfo.attrs = {
				["EWR"] = true,
			}
			saminfo.update = 15
		end
	end

	return saminfo
end

local CheckSAM = class("CheckSAM", Check)
function CheckSAM:__init()
	Check.__init(self, "SAM")
end

function CheckSAM:check(data)
	if adtypes[data.objtype] == nil then
		return true
	end

	if data.attackrange == dctenum.DEFAULTRANGE or
	   data.displayname == dctenum.DEFAULTNAME then
		local saminfo = classify(data)

		if data.attackrange == dctenum.DEFAULTRANGE then
			data.attackrange = saminfo.range
		end

		if data.displayname == dctenum.DEFAULTNAME then
			data.displayname = saminfo.name
		end

		data.radarupdate = saminfo.update
		data.radarattrs = saminfo.attrs or { ["SAM SR"] = true, }
		data.radardetection = {
			Controller.Detection.RADAR,
			Controller.Detection.OPTIC,
		}
	end
	data.threats = {
		["Battle airplanes"] = true,
		["Battleplanes"]     = true,
	}

	return true
end

return CheckSAM
