-- SPDX-License-Identifier: LGPL-3.0

require("libs")

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

local function processCategory(id, cat, tbl, coa)
	if tbl == nil or tbl.group == nil then
		return
	end
	for _, grp in ipairs(tbl.group) do
		coalition.addGroup(id, string.upper(cat), grp)
		if grp.units then
			for _, unit in ipairs(grp.units) do
				local newab = {
					["name"]   = env.getValueDictByKey(unit.name),
					["id"]     = unit.unitId,
					["exists"] = true,
					["coalition"] = coalition.side[string.upper(coa)],
					["airbaseCategory"] = Airbase.Category.SHIP,
				}
				local ab = Airbase(newab)
				ab.desc.attributes.Airfields = nil
				ab.desc.attributes["Aircraft Carriers"] = true
				ab.desc.attributes["AircraftCarrier"] = true
			end
		end
	end
end

local function setupDCSEnv()
	local warehouses = libs.utils.readlua(
			libs.utils.join_paths(lfs.tempdir(), "warehouses"),
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

	local catmap = {
		"ship",
	}

	-- create all mission placed airbases; ships & farps
	for coa, coatbl in pairs(env.mission.coalition) do
		for _, cntrytbl in ipairs(coatbl.country) do
			for _, cat in pairs(catmap) do
				processCategory(cntrytbl.id, cat, cntrytbl[cat], coa)
			end
		end
	end
end

local dcttest = {}

--- Simulate dct being included into the runtime and then DCS's
-- MissionScripting.lua removing some functions.
function dcttest.setupRuntime()
	setupDCSEnv()
	require("dct")

	local function sanitizeModule(name)
		_G[name] = nil
		package.loaded[name] = nil
	end

	do
		--sanitizeModule('os')
		--sanitizeModule('io')
		--sanitizeModule('lfs')
		--_G['require'] = nil
		--_G['loadlib'] = nil
		--_G['package'] = nil
	end
end

function dcttest.createPlayer(playername)
	local grp = Group(4, {
		["id"] = 9,
		["name"] = "VMFA251 - Enfield 1-1",
		["coalition"] = coalition.side.BLUE,
		["exists"] = true,
	})

	local unit1 = Unit({
		["name"] = "pilot1",
		["exists"] = true,
		["desc"] = {
			["typeName"] = "FA-18C_hornet",
			["displayName"] = "F/A-18C Hornet",
			["attributes"] = {},
		},
	}, grp, playername or "bobplayer")
	return unit1, grp
end

function dcttest.setModelTime(time)
	timer.model_time = time
end

function dcttest.addModelTime(time)
	timer.model_time = timer.model_time + time
end

function dcttest.runSched()
	for func, data in pairs(timer.schedfunctbl) do
		if timer.model_time > data.time then
			data.time = func(data.arg, timer.model_time)
			if not (data.time ~= nil and
			   type(data.time) == "number") then
				timer.schedfunctbl[func] = nil
			end
		end
	end
end

function dcttest.runEventHandlers(event)
	world.onEvent(event)
end

function dcttest.fastForward(time, step)
	for _ = 1,time or 100,1 do
		dcttest.runSched()
		dcttest.addModelTime(step or 3)
	end
end

function dcttest.createEvent(eventdata, player)
	local event = {}
	local objref

	if eventdata.object.objtype == Object.Category.UNIT then
		objref = Unit.getByName(eventdata.object.name)
	elseif eventdata.object.objtype == Object.Category.STATIC then
		objref = StaticObject.getByName(eventdata.object.name)
	elseif eventdata.object.objtype == Object.Category.GROUP then
		objref = Group.getByName(eventdata.object.name)
	else
		assert(false, "other object types not supported")
	end

	assert(objref, "objref is nil")
	event.id = eventdata.id
	event.time = timer.model_time
	if event.id == world.event.S_EVENT_DEAD then
		event.initiator = objref
		objref.clife = 0
	elseif event.id == world.event.S_EVENT_HIT then
		event.initiator = player
		event.weapon = nil
		event.target = objref
		objref.clife = objref.clife - eventdata.object.life
	else
		assert(false, "other event types not supported: "..
			tostring(event.id))
	end
	return event
end

_G.dcttest = dcttest
