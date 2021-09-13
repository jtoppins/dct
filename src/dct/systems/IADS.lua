local Logger      = require("dct.libs.Logger").getByName("IADS")
local Command     = require("dct.Command")
local class       = require("libs.class")
local utils       = require("libs.utils")

-- luacheck: max_cyclomatic_complexity 21, ignore 241
-- luacheck: ignore 311

-- Ranges at which SAM sites are considered close enough to activate, in meters
local rangeTbl = {
	["Kub 1S91 str"] = 52000,
	["S-300PS 40B6M tr"] =  100000,
	["Osa 9A33 ln"] = 25000,
	["snr s-125 tr"] = 60000,
	["SNR_75V"] = 65000,
	["Dog Ear radar"] = 26000,
	["SA-11 Buk LN 9A310M1"] = 43000,
	["Hawk tr"] = 60000,
	["Tor 9A331"] = 50000,
	["rapier_fsa_blindfire_radar"] = 6000,
	["Patriot STR"] = 100000,
	["Roland ADS"] = 7500,
	["HQ-7_STR_SP"] = 10000,
}
-- Point defense units are not turned off when they detect an ARM
local pointDefense = {
	["Tor 9A331"] = true,
}

-- IADS settings
-- 1 = radio detection of ARM launch on, 0 = radio detection of ARM launch off
local RadioDetect = true
-- 1 = EWR detection of ARMs on, 0 = EWR detection of ARMs off
local EwrArmDetect = true
-- 1 = SAM detectionf of ARMs on, 0 = SAM detection of ARMs off
local SamArmDetect = true
--Range of an EWR in which SAMs are controlled
local EWRAssocRng = 80000
--Range within which ARM launches are detected via radio
local RadioHideRng = 120000
-- %age chance of radio detection of ARM launch causing SAM shutdown
local ARMHidePct = 20
-- %age chance EWR detection of ARM causing SAM shutdown
local EwrOffChance = 25
-- %age chance SAM detection of ARM causings SAM shuttown
local SamOffChance = 75
-- trk persistance time after last detection
local trkMem = 20
-- Have controlled SAMs stay off if no ammo remaining.
local contSamAmmo = true
-- Have uncontrolled SAMs stay off if no ammo remaining
local uncontSamAmmo = false

local function getDist(point1, point2)
	local dX = point1.x - point2.x
	local dZ = point1.z - point2.z
	return math.sqrt(dX*dX + dZ*dZ)
end

local function getDist3D(point1, point2)
	local dX = point1.x - point2.x
	local dY = point1.y - point2.y
	local dZ = point1.z - point2.z
	return math.sqrt(dX*dX + dZ*dZ + dY*dY)
end

local function isFlying(object)
	return object ~= nil and object:isExist() and object:inAir()
end

local function isARM(object)
	return object ~= nil and
	       object:getCategory() == Object.Category.WEAPON and
	       object:getDesc().guidance == Weapon.GuidanceType.RADAR_PASSIVE
end

local function getDetectedTargets(group)
	if group == nil or not group:isExist() then
		return {}
	end
	return group:getController():getDetectedTargets(Controller.Detection.RADAR)
end

local IADS = class()
function IADS:__init(cmdr)
	assert(cmdr, "value error: cmdr must be a non-nil value")
	self.owner    = cmdr.owner
	self.SAMSites = {}
	self.EWRSites = {}
	self.AewAC    = {}
	self.toHide   = {}
	self.trkFiles = {}

	local theater = require("dct.Theater").singleton()
	local prefix = string.format("iads[%s]",
		utils.getkey(coalition.side, cmdr.owner))

	theater:addObserver(
		self.sysIADSEventHandler, self, prefix..".eventhandler")

	-- Initialization
	theater:queueCommand(10, Command(prefix..".populateLists",
		self.populateLists, self))
	theater:queueCommand(15, Command(prefix..".disableAllSAMs",
		self.disableAllSAMs, self))

	-- Periodic
	theater:queueCommand(10, Command(prefix..".timeoutTracks",
		self.timeoutTracks, self))
	theater:queueCommand(10, Command(prefix..".EWRtrkFileBuild",
		self.EWRtrkFileBuild, self))
	theater:queueCommand(10, Command(prefix..".SAMtrkFileBuild",
		self.SAMtrkFileBuild, self))
	theater:queueCommand(10, Command(prefix..".AWACStrkFileBuild",
		self.AWACStrkFileBuild, self))
	theater:queueCommand(10, Command(prefix..".SAMCheckHidden",
		self.SAMCheckHidden, self))
	theater:queueCommand(10, Command(prefix..".BlinkSAM",
		self.BlinkSAM, self))
	theater:queueCommand(10, Command("iads.EWRSAMOnRequest",
		self.EWRSAMOnRequest, self))
end

function IADS:getSamByName(name)
	return self.SAMSites[name]
end

function IADS:rangeOfSAM(gp)
	local maxRange = 0
	for _, unit in pairs(gp:getUnits()) do
		if unit:hasAttribute("SAM TR") and
			rangeTbl[unit:getTypeName()] then
			local samRange  = rangeTbl[unit:getTypeName()]
			if maxRange < samRange then
				maxRange = samRange
			end
		end
	end
	return maxRange
end

local function ammoCheck(site)
	local wpns = {
		[Weapon.GuidanceType.RADAR_ACTIVE]      = true,
		[Weapon.GuidanceType.RADAR_SEMI_ACTIVE] = true,
	}

	for _, unt in pairs(site.group:getUnits()) do
		local ammo = unt:getAmmo() or {}
		for j=1, #ammo do
			if wpns[ammo[j].desc.guidance] == true and
			   ammo[j].count > 0 then
				return true
			end
		end
	end
	return false
end

function IADS:enableSAM(site)
	if site.Hidden or site.Enabled or not site.group:isExist() then
		return
	end

	local hasAmmo = ammoCheck(site)
	if next(site.ControlledBy) ~= nil then
		if contSamAmmo and not hasAmmo then
			return
		end
	else
		if uncontSamAmmo and not hasAmmo then
			return
		end
	end

	Logger:debug("enableSam(%s)", site.Name)
	site.group:enableEmission(true)
	site.group:getController():setOption(
		AI.Option.Ground.id.ALARM_STATE,
		AI.Option.Ground.val.ALARM_STATE.RED)
	site.Enabled = true
end

function IADS:disableSAM(site)
	if not site.Enabled or not site.group:isExist() then
		return
	end

	local inRange = false
	if site.trkFiles then
		for _, trk in pairs(site.trkFiles) do
			if trk.Position ~= nil and
			   getDist(site.Location, trk.Position) < (site.EngageRange * 1.15) then
				inRange = true
			end
		end
	end

	if not inRange then
		Logger:debug("disableSam(%s)", site.Name)
		site.group:getController():setOption(
			AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.GREEN)
		site.Enabled = false
	end
end

function IADS:disableAllSAMs()
	for _, SAM in pairs(self.SAMSites) do
		self:disableSAM(SAM)
	end
end

function IADS:hideSAM(site)
	if site ~= nil then
		Logger:debug("hideSam(%s)", site.Name)
		site.group:enableEmission(false)
		site.Enabled = false
	end
end

function IADS:associateSAMS()
	for _, EWR in pairs(self.EWRSites) do
		EWR.SAMsControlled = {}
		for _, SAM in pairs(self.SAMSites) do
			if getDist3D(SAM.Location, EWR.Location) < EWRAssocRng then
				EWR.SAMsControlled[SAM.Name] = SAM
				SAM.ControlledBy[EWR.Name] = EWR
			end
		end
	end
end

function IADS:magnumHide(site)
	if not pointDefense[site.Type] and not site.Hidden then
		local randomTime = math.random(15,35)
		self.toHide[site.Name] = randomTime
		site.HiddenTime = math.random(65,100)+randomTime
		site.Hidden = true
	end
end

function IADS:prevDetected(Sys, ARM)
	for id, prev in pairs(Sys.ARMDetected) do
		if prev:isExist() then
			if ARM:getName() == prev:getName() then
				return true
			end
		else
			Sys.ARMDetected[id] = nil
		end
	end
end

function IADS:addtrkFile(site, target)
	local trkName = target.object.id_
	site.trkFiles[trkName] = {}
	site.trkFiles[trkName]["Name"] = trkName
	site.trkFiles[trkName]["Object"] = target.object
	site.trkFiles[trkName]["LastDetected"] = timer.getAbsTime()
	if target.distance then
		site.trkFiles[trkName]["Position"] = target.object:getPoint()
		site.trkFiles[trkName]["Velocity"] = target.object:getVelocity()
	end
	if target.type then
		site.trkFiles[trkName]["Category"] = target.object:getCategory()
		site.trkFiles[trkName]["Type"] = target.object:getTypeName()
	end
	if site.Datalink then
		site.trkFiles[trkName]["Datalink"] = true
	end
	self.trkFiles[trkName] =
		utils.mergetables(self.trkFiles[trkName] or {}, site.trkFiles[trkName])
end

function IADS:EWRtrkFileBuild()
	for _, EWR in pairs(self.EWRSites) do
		for _, target in pairs(getDetectedTargets(EWR.EWRGroup)) do
			if isFlying(target.object) then
				self:addtrkFile(EWR, target)
				if EwrArmDetect and
				   isARM(target.object) and
				   not self:prevDetected(EWR, target.object) then
					EWR.ARMDetected[target.object:getName()] = target.object
					for _, SAM in pairs(EWR.SAMsControlled) do
						if math.random(1,100) < EwrOffChance then
							Logger:debug("'%s' detected ARM launch on radar; '%s' hiding",
								EWR.Name, EWR.Name)
							self:magnumHide(SAM)
						end
					end
				end
			end
		end
	end
	return 2
end

function IADS:SAMtrkFileBuild()
	for _, SAM in pairs(self.SAMSites) do
		for _, target in pairs(getDetectedTargets(SAM.group)) do
			if isFlying(target.object) then
				self:addtrkFile(SAM, target)
				if SamArmDetect and
				   isARM(target.object) and
				   not self:prevDetected(SAM, target.object) then
					SAM.ARMDetected[target.object:getName()] = target.object
					if math.random(1,100) < SamOffChance then
						Logger:debug("'%s' detected ARM launch on radar", SAM.Name)
						self:magnumHide(SAM)
					end
				end
			end
		end
	end
	return 2
end

function IADS:AWACStrkFileBuild()
	for _, AWACS in pairs(self.AewAC) do
		for _, target in pairs(getDetectedTargets(AWACS.AWACSGroup)) do
			if isFlying(target.object) then
				self:addtrkFile(AWACS, target)
			end
		end
	end
	return 2
end

function IADS:EWRSAMOnRequest()
	for _, SAM in pairs(self.SAMSites) do
		if next(SAM.ControlledBy) ~= nil then
			local viableTarget = false
			for _, EWR in pairs(SAM.ControlledBy) do
				for _, target in pairs(EWR.trkFiles) do
					if target.Position and
						getDist(SAM.Location, target.Position) < SAM.EngageRange then
						viableTarget = true
					end
				end
			end
			if viableTarget then
				self:enableSAM(SAM)
			else
				self:disableSAM(SAM)
			end
		end
	end
	return 2
end

function IADS:SAMCheckHidden()
	for _, SAM in pairs(self.SAMSites) do
		if SAM.Hidden then
			SAM.HiddenTime = SAM.HiddenTime - 2
			if SAM.HiddenTime < 1 then
				SAM.Hidden = false
			end
		end
	end
	for site, time in pairs(self.toHide) do
		if time < 0 then
			self:hideSAM(self:getSamByName(site))
			self.toHide[site] = nil
		else
			self.toHide[site] = time - 2
		end
	end
	return 2
end

function IADS:BlinkSAM()
	for _, SAM in pairs(self.SAMSites) do
		if next(SAM.ControlledBy) == nil then
			if SAM.BlinkTimer < 1  and (not SAM.Hidden) then
				if SAM.Enabled then
					self:disableSAM(SAM)
					SAM.BlinkTimer = math.random(30,60)
				else
					self:enableSAM(SAM)
					SAM.BlinkTimer = math.random(30,60)
				end
			else
				SAM.BlinkTimer = SAM.BlinkTimer - 5
			end
		end
	end
	return 5
end

function IADS:checkGroupRole(gp)
	if gp == nil or gp:getCoalition() ~= self.owner then
		return
	end
	local isEWR = false
	local isSAM = false
	local isAWACS = false
	local hasDL = false
	local samType
	local numSAMRadars = 0
	local numEWRRadars = 0
	if gp:getCategory() == Group.Category.GROUND then
		for _, unt in pairs(gp:getUnits()) do
			if unt:hasAttribute("EWR") then
				isEWR = true
				numEWRRadars = numEWRRadars + 1
			elseif unt:hasAttribute("SAM TR") then
				isSAM = true
				samType = unt:getTypeName()
				numSAMRadars = numSAMRadars + 1
			end
			if unt:hasAttribute("Datalink") then
				hasDL = true
			end
		end
		if isEWR then
			self.EWRSites[gp:getName()] = {
				["Name"] = gp:getName(),
				["EWRGroup"] = gp,
				["SAMsControlled"] = {},
				["Location"] = gp:getUnit(1):getPoint(),
				["numEWRRadars"] = numEWRRadars,
				["ARMDetected"] = {},
				["Datalink"] = hasDL,
				["trkFiles"] = {},
			}
			return gp:getName()
		elseif isSAM and self:rangeOfSAM(gp) then
			self.SAMSites[gp:getName()] = {
				["Name"] = gp:getName(),
				["group"] = gp,
				["Type"] = samType,
				["Location"] = gp:getUnit(1):getPoint(),
				["numSAMRadars"] = numSAMRadars,
				["EngageRange"] = self:rangeOfSAM(gp),
				["ControlledBy"] = {},
				["Enabled"] = true,
				["Hidden"] = false,
				["BlinkTimer"] = 0,
				["ARMDetected"] = {},
				["Datalink"] = hasDL,
				["trkFiles"] = {},
			}
			return gp:getName()
		end
	elseif gp:getCategory() == Group.Category.AIRPLANE then
		local numAWACS = 0
		for _, unt in pairs(gp:getUnits()) do
			if unt:hasAttribute("AWACS") then
				isAWACS = true
				numAWACS = numAWACS+1
			end
			if unt:hasAttribute("Datalink") then
				hasDL = true
			end
		end
		if isAWACS then
			self.AewAC[gp:getName()] = {
				["Name"] = gp:getName(),
				["AWACSGroup"] = gp,
				["Location"] = gp:getUnit(1):getPoint(),
				["numAWACS"] = numAWACS,
				["Datalink"] = hasDL,
				["trkFiles"] = {},
			}
			return gp:getName()
		end
	end
end

function IADS:onDeath(event)
	if event.initiator:getCategory() == Object.Category.UNIT and
	   event.initiator:getGroup() ~= nil then
		local eventUnit = event.initiator
		local eventGroup = event.initiator:getGroup()
		for _, SAM in pairs(self.SAMSites) do
			if eventGroup:getName() == SAM.Name then
				if eventUnit:hasAttribute("SAM TR") then
					SAM.numSAMRadars = SAM.numSAMRadars - 1
				end
				if SAM.numSAMRadars < 1 then
					for _, EWR in pairs(self.EWRSites) do
						for _, SAMControlled in pairs(EWR.SAMsControlled) do
							if SAMControlled.Name == SAM.Name then
								EWR.SAMsControlled[SAM.Name] = nil
							end
						end
					end
					self.SAMSites[SAM.Name] = nil
				end
			end
		end
		for _, EWR in pairs(self.EWRSites) do
			if eventGroup:getName() == EWR.Name then
				if eventUnit:hasAttribute("EWR") then
					EWR.numEWRRadars = EWR.numEWRRadars - 1
					if EWR.numEWRRadars < 1 then
						for _, SAM in pairs(self.SAMSites) do
							for _, controllingEWR in pairs(SAM.ControlledBy) do
								if controllingEWR.Name == EWR.Name then
									SAM.ControlledBy[EWR.Name] = nil
								end
							end
						end
						self.EWRSites[EWR.Name] = nil
					end
				end
			end
			for _, AWACS in pairs(self.AewAC) do
				if eventGroup:getName() == EWR.Name then
					if eventUnit:hasAttribute("AWACS") then
						AWACS.numAWACS = AWACS.numAWACS - 1
						if AWACS.numAWACS < 1 then
							self.AewAC[AWACS.Name] = nil
						end
					end
				end
			end
		end
	end
end

function IADS:onShot(event)
	if RadioDetect and event.initiator:getCoalition() ~= self.owner then
		if isARM(event.weapon) then
			local WepPt = event.weapon:getPoint()
			for _, SAM in pairs(self.SAMSites) do
				if math.random(1,100) < ARMHidePct and
					getDist(SAM.Location, WepPt) < RadioHideRng then
					Logger:debug("'%s' detected ARM launch on radio", SAM.Name)
					self:magnumHide(SAM)
				end
			end
		end
	end
end

function IADS:onBirth(event)
	if event.initiator:getCategory() ~= Object.Category.UNIT then
		return
	end
	local gp = event.initiator:getGroup()
	local name = self:checkGroupRole(gp)
	if name ~= nil then
		self:associateSAMS()
		if self.SAMSites[name] ~= nil then
			self:disableSAM(self.SAMSites[name])
		end
	end
end

function IADS:populateLists()
	for _, gp in pairs(coalition.getGroups(self.owner)) do
		self:checkGroupRole(gp)
	end
	self:associateSAMS()
end

local function trkTimedOut(trk, time)
	return time - trk.LastDetected > trkMem or not isFlying(trk.Object)
end

function IADS:timeoutTracks()
	local time = timer.getAbsTime()
	for _, EWR in pairs(self.EWRSites) do
		for _, trk in pairs(EWR.trkFiles) do
			if trkTimedOut(trk, time) then
				EWR.trkFiles[trk.Name] = nil
			end
		end
	end
	for _, SAM in pairs(self.SAMSites) do
		for _, trk in pairs(SAM.trkFiles) do
			if trkTimedOut(trk, time) then
				SAM.trkFiles[trk.Name] = nil
			end
		end
	end
	for _, AWACS in pairs(self.AewAC) do
		for _, trk in pairs(AWACS.trkFiles) do
			if trkTimedOut(trk, time) then
				AWACS.trkFiles[trk.Name] = nil
			end
		end
	end
	for _, trk in pairs(self.trkFiles) do
		if trkTimedOut(trk, time) then
			self.trkFiles[trk.Name] = nil
		end
	end
	return 2
end

function IADS:sysIADSEventHandler(event)
	local relevents = {
		[world.event.S_EVENT_DEAD]      = self.onDeath,
		[world.event.S_EVENT_SHOT]      = self.onShot,
		[world.event.S_EVENT_BIRTH]     = self.onBirth,
	}
	if relevents[event.id] == nil then
		return
	end
	relevents[event.id](self, event)
end

return IADS
