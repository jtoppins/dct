local Logger      = require("dct.libs.Logger").getByName("IADS")
local Command     = require("dct.Command")
local class       = require("libs.class")

-- Ranges at which SAM sites are
-- considered close enough to activate in meters

-- luacheck: max_cyclomatic_complexity 21, ignore 241
-- luacheck: ignore 311
local trkFiles = {
	["SAM"] = {},
	["EWR"] = {},
	["AWACS"] = {},
}

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
-- If true IADS script is active
--local IADSEnable = true
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

local IADS = class()
function IADS:__init(cmdr)
	assert(cmdr, "value error: cmdr must be a non-nil value")
	self.owner    = cmdr.owner
	self.SAMSites = {}
	self.EWRSites = {}
	self.AewAC    = {}
	self.toHide   = {}

	local theater = require("dct.Theater").singleton()
	theater:addObserver(self.sysIADSEventHandler, self,
		"iads.eventhandler")
	theater:queueCommand(10, Command("iads.populateLists",
		self.populateLists, self))
	theater:queueCommand(10, Command("iads.monitortrks",
		self.monitortrks, self))
	theater:queueCommand(10, Command("iads.SAMCheckHidden",
		self.SAMCheckHidden, self))
	theater:queueCommand(10, Command("iads.BlinkSAM",
		self.BlinkSAM, self))
	theater:queueCommand(10, Command("iads.EWRSAMOnRequest",
		self.EWRSAMOnRequest, self))
	theater:queueCommand(15, Command("iads.disableAllSAMs",
		self.disableAllSAMs, self))
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

function IADS:disableSAM(site)
	if not site.Enabled then
		return nil
	end

	local inRange = false
	if site.trkFiles then
		for _, trk in pairs(site.trkFiles) do
			if trk.Position and getDist(site.Location, trk.Position)
				< (site.EngageRange * 1.15) then
				inRange = true
			end
		end
	end

	if inRange ~= true then
		site.group:getController():setOption(
			AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.GREEN)
		site.Enabled = false
		env.info("SAM: "..site.Name.." disabled")
	end
	return nil
end

function IADS:hideSAM(site)
	site.group:getController():setOption(
		AI.Option.Ground.id.ALARM_STATE,
		AI.Option.Ground.val.ALARM_STATE.GREEN)
	site.Enabled = false
	env.info("SAM: "..site.Name.." hidden")
	return nil
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
	if site.Hidden or site.Enabled then
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

	site.group:getController():setOption(
		AI.Option.Ground.id.ALARM_STATE,
		AI.Option.Ground.val.ALARM_STATE.RED)
	site.Enabled = true
	env.info("SAM: "..site.Name.." enabled")
end

function IADS:associateSAMS()
	for _, EWR in pairs(self.EWRSites) do
		EWR.SAMsControlled = {}
		for _, SAM in pairs(self.SAMSites) do
			if SAM.group:getCoalition() == EWR.EWRGroup:getCoalition()
				and getDist3D(SAM.Location, EWR.Location) < EWRAssocRng then
				EWR.SAMsControlled[SAM.Name] = SAM
				SAM.ControlledBy[EWR.Name] = EWR
			end
		end
	end
end

function IADS:magHide(site)
	if site.Type ~= "Tor 9A331" and not site.Hidden then
		local randomTime = math.random(15,35)
		self.toHide[site.Name] = randomTime
		site.HiddenTime = math.random(65,100)+randomTime
		site.Hidden = true
	end
end

function IADS:prevDetected(Sys, ARM)
	for _, prev in pairs(Sys.ARMDetected) do
		if prev:isExist() then
			if ARM:getName() == prev:getName() then
				return true
			end
		else
			prev = nil
		end
	end
end

function IADS:addtrkFile(site, targets)
	if targets.object:isExist() then
		local trkName = targets.object.id_
		site.trkFiles[trkName] = {}
		site.trkFiles[trkName]["Name"] = trkName
		site.trkFiles[trkName]["Object"] = targets.object
		site.trkFiles[trkName]["LastDetected"] = timer.getAbsTime()
		if targets.distance then
			site.trkFiles[trkName]["Position"] = targets.object:getPoint()
			site.trkFiles[trkName]["Velocity"] = targets.object:getVelocity()
		end
		if targets.type then
			site.trkFiles[trkName]["Category"] = targets.object:getCategory()
			site.trkFiles[trkName]["Type"] = targets.object:getTypeName()
		end
		if site.Datalink then
			site.trkFiles[trkName]["Datalink"] = true
		end
	end
end

function IADS:EWRtrkFileBuild()
	for _, EWR in pairs(self.EWRSites) do
		local det = EWR.EWRGroup:getController():getDetectedTargets(Controller.Detection.RADAR)
		for _, targets in pairs(det) do
			if targets.object and targets.object:isExist()
				and targets.object:inAir() then
				local trkName = targets.object.id_
				self:addtrkFile(EWR, targets)
				trkFiles["EWR"][trkName] = EWR.trkFiles[trkName]
				if targets.object:getCategory() == Object.Category.WEAPON
					and targets.object:getDesc().guidance == Weapon.GuidanceType.RADAR_PASSIVE
					and EwrArmDetect and not self:prevDetected(EWR, targets.object) then
					EWR.ARMDetected[targets.object:getName()] = targets.object
					for _, SAM in pairs(EWR.SAMsControlled) do
						if math.random(1,100) < EwrOffChance then
							self:magHide(SAM)
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
		local det = SAM.group:getController():getDetectedTargets(Controller.Detection.RADAR)
		for _, targets in pairs(det) do
			if targets.object and targets.object:isExist()
				and targets.object:inAir() then
				local trkName = targets.object.id_
				self:addtrkFile(SAM, targets)
				trkFiles["SAM"][trkName] = SAM.trkFiles[trkName]
				if targets.object:getCategory() == Object.Category.WEAPON
					and targets.object:getDesc().guidance == Weapon.GuidanceType.RADAR_PASSIVE
					and SamArmDetect and not self:prevDetected(SAM, targets.object) then
					SAM.ARMDetected[targets.object:getName()] = targets.object
					if math.random(1,100) < SamOffChance then
						self:magHide(SAM)
					end
				end
			end
		end
	end
	return 2
end

function IADS:AWACStrkFileBuild()
	for _, AWACS in pairs(self.AewAC) do
		local det = AWACS.AWACSGroup:getController():getDetectedTargets(Controller.Detection.RADAR)
		for _, targets in pairs(det) do
			if targets.object and targets.object:isExist()
				and targets.object:inAir() then
				local trkName = targets.object.id_
				self:addtrkFile(AWACS, targets)
				trkFiles["AWACS"][trkName] = AWACS.trkFiles[trkName]
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
			self.hideSAM(self:getSamByName(site))
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
			--env.info("SAM: "..SAM.Name.." is uncontrolled")
			if SAM.BlinkTimer < 1  and (not SAM.Hidden) then
				if SAM.Enabled then
					--env.info("Blink Off")
					self:disableSAM(SAM)
					SAM.BlinkTimer = math.random(30,60)
				else
					--env.info("Blink On")
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
	if gp == nil then
		return
	end
	local isEWR = false
	local isSAM = false
	local isAWACS = false
	local hasDL = false
	local samType
	local numSAMRadars = 0
	local numEWRRadars = 0
	if gp:getCategory() == 2 then
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
	elseif gp:getCategory() == 0 then
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
				["numAWACS"] = numAWACS,
				["Datalink"] = hasDL,
				["trkFiles"] = {},
			}
			return gp:getName()
		end
	end
end

function IADS:onDeath(event)
	if event.initiator:getCategory() == Object.Category.UNIT
		and event.initiator:getGroup() then
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
	if RadioDetect then
		if event.weapon then
			local ordnance = event.weapon
			local WepPt = ordnance:getPoint()
			local WepDesc = ordnance:getDesc()
			if WepDesc.guidance == Weapon.GuidanceType.RADAR_PASSIVE then
				for _, SAM in pairs(self.SAMSites) do
					if math.random(1,100) < ARMHidePct and
						getDist(SAM.Location, WepPt) < RadioHideRng then
						self:magHide(SAM)
					end
				end
			end
		end
	end
end

function IADS:onBirth(event)
	if event.initiator:getCategory() ~= Object.Category.Unit then
		return
	end
	local gp = event.initiator:getGroup()
	self:checkGroupRole(gp)
	self:associateSAMS()
end

function IADS:disableAllSAMs()
	for _, SAM in pairs(self.SAMSites) do
		SAM.group:getController():setOption(AI.Option.Ground.id.ALARM_STATE,
			AI.Option.Ground.val.ALARM_STATE.GREEN)
		SAM.Enabled = false
	end
	return nil
end

function IADS:populateLists()
	for _, gp in pairs(coalition.getGroups(1)) do
		self:checkGroupRole(gp)
	end
	self:associateSAMS()
	return nil
end

function IADS:monitortrks()
	self:EWRtrkFileBuild()
	self:SAMtrkFileBuild()
	self:AWACStrkFileBuild()
	for _, EWR in pairs(self.EWRSites) do
		for _, trk in pairs(EWR.trkFiles) do
			if ((timer.getAbsTime() - trk.LastDetected) > trkMem or
				(not trk.Object:isExist()) or (not trk.Object:inAir())) then
				EWR.trkFiles[trk.Name] = nil
				trkFiles.EWR[trk.Name] = nil
			end
		end
	end
	for _, SAM in pairs(self.SAMSites) do
		for _, trk in pairs(SAM.trkFiles) do
			if ((timer.getAbsTime() - trk.LastDetected) > trkMem or
				(not trk.Object:isExist()) or (not trk.Object:inAir())) then
				SAM.trkFiles[trk.Name] = nil
				trkFiles.SAM[trk.Name] = nil
			end
		end
	end
	for _, AWACS in pairs(self.AewAC) do
		for _, trk in pairs(AWACS.trkFiles) do
			if ((timer.getAbsTime() - trk.LastDetected) > trkMem or
				(not trk.Object:isExist()) or (not trk.Object:inAir())) then
				AWACS.trkFiles[trk.Name] = nil
				trkFiles.AWACS[trk.Name] = nil
			end
		end
	end
	return 2
end

function IADS:sysIADSEventHandler(event)
	local relevents = {
		[world.event.S_EVENT_DEAD]                = self.onDeath,
		[world.event.S_EVENT_SHOT]                = self.onShot,
		[world.event.S_EVENT_BIRTH]               = self.onBirth,
	}
	if relevents[event.id] == nil then
		Logger:debug("sysIADSEventHandler - not relevent event: "..
		tostring(event.id))
		return
	end
	relevents[event.id](self, event)
end

return IADS
