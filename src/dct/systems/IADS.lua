local Logger      = require("dct.Logger").getByName("IADS")
local Command     = require("dct.Command")
local class       = require("libs.class")


local SAMRangeLookupTable = { -- Ranges at which SAM sites are considered close enough to activate in m
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
local IADSEnable = true -- If true IADS script is active
local IADSRadioDetection = true -- 1 = radio detection of ARM launch on, 0 = radio detection of ARM launch off
local IADSEWRARMDetection = true -- 1 = EWR detection of ARMs on, 0 = EWR detection of ARMs off
local IADSSAMARMDetection = true -- 1 = SAM detectionf of ARMs on, 0 = SAM detection of ARMs off
local EWRAssociationRange = 80000 --Range of an EWR in which SAMs are controlled
local IADSARMHideRangeRadio = 120000 --Range within which ARM launches are detected via radio
local IADSARMHidePctage = 20 -- %age chance of radio detection of ARM launch causing SAM shutdown
local EWRARMShutdownChance = 25 -- %age chance EWR detection of ARM causing SAM shutdown
local SAMARMShutdownChance = 75-- %age chance SAM detection of ARM causings SAM shuttown
local trackMemory = 20 -- Track persistance time after last detection
local controlledSAMNoAmmo = true -- Have controlled SAMs stay off if no ammo remaining.
local uncontrolledSAMNoAmmo = false -- Have uncontrolled SAMs stay off in no ammo remaining
local SAMSites = {}
local EWRSites = {}
local AWACSAircraft = {}
local TrackFiles = {["SAM"] = {},
              ["EWR"] = {},
              ["AWACS"] = {},}

local IADS = class()


local function tablelength(T)
  if T == nil then
    return 0
  end
  local count = 0
  for _, item in pairs(T) do
    if item~=nil then
      count = count + 1
    end
  end
  return count
end

function IADS:getDistance(point1, point2)
  local x1 = point1.x
  local y1 = point1.y
  local z1 = point1.z
  local x2 = point2.x
  local y2 = point2.y
  local z2 = point2.z
  local dX = math.abs(x1-x2)
  local dY = math.abs(y1-y2)
  local dZ = math.abs(z1-z2)
  local distance = math.sqrt(dX*dX + dZ*dZ)
  return distance
end

function IADS:getDistance3D(point1, point2)
  local x1 = point1.x
  local y1 = point1.y
  local z1 = point1.z
  local x2 = point2.x
  local y2 = point2.y
  local z2 = point2.z
  local dX = math.abs(x1-x2)
  local dY = math.abs(y1-y2)
  local dZ = math.abs(z1-z2)
  local distance = math.sqrt(dX*dX + dZ*dZ + dY*dY)
  return distance
end

function IADS:rangeOfSAM(gp)
  local maxRange = 0
  for _, unit in pairs(gp:getUnits()) do
    if unit:hasAttribute("SAM TR") and SAMRangeLookupTable[unit:getTypeName()] then
      local samRange  = SAMRangeLookupTable[unit:getTypeName()]
      if maxRange < samRange then
        maxRange = samRange
      end
    end
  end
  return maxRange
end

function IADS:disableSAM(site)
  if tablelength(site.trackFiles) > 0 then
     self.theater:queueCommand(math.random(60,120), Command(self.disableSAM, self, site))
  elseif site.Enabled then
    site.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
    site.Enabled = false
  end
end

function IADS:hideSAM(site)
  site.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
  site.Enabled = false
end

function IADS:enableSAM(site)
  if (not site.Hidden) and (not site.Enabled) then
  local hasAmmo = false
  local ammo
    if tablelength(site.ControlledBy) > 0 then
      for _, unt in pairs(site.SAMGroup:getUnits()) do
         ammo = unt:getAmmo()
         if ammo then
           for j=1, #ammo do
            if ammo[j].count > 0 and ammo[j].desc.guidance == 3 or ammo[j].desc.guidance == 4 then
              hasAmmo = true
           end
          end
        end
      end
      if controlledSAMNoAmmo and (not hasAmmo) then
      else
        site.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,2)
        site.Enabled = true
      end
    else
      for _, unt in pairs(site.SAMGroup:getUnits()) do
         ammo = unt:getAmmo()
         if ammo then
           for j=1, #ammo do
            if ammo[j].count > 0 and ammo[j].desc.guidance == 3 or ammo[j].desc.guidance == 4 then
              hasAmmo = true
           end
          end
        end
      end
      if uncontrolledSAMNoAmmo and not hasAmmo  then
      else
        site.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,2)
        site.Enabled = true
      end
    end
  end
end

function IADS:associateSAMS()
  for _, EWR in pairs(EWRSites) do
    EWR.SAMsControlled = {}
    for _, SAM in pairs(SAMSites) do
      if SAM.SAMGroup:getCoalition() == EWR.EWRGroup:getCoalition() and self:getDistance3D(SAM.Location, EWR.Location) < EWRAssociationRange then
        EWR.SAMsControlled[SAM.Name] = SAM
        SAM.ControlledBy[EWR.Name] = EWR
      end
    end
  end
end

function IADS:magnumHide(site)
  if site.Type == "Tor 9A331" then
  elseif not site.Hidden then
    local randomTime = math.random(15,35)
    self.theater:queueCommand(randomTime, Command(self.hideSAM, self, site))
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

function IADS:EWRTrackFileBuild()
  for _, EWR in pairs(EWRSites) do
    local detections = EWR.EWRGroup:getController():getDetectedTargets(Controller.Detection.RADAR)
    for j, targets in pairs(detections) do
      if targets.object and targets.object:inAir() then
        local trackName = targets.object.id_
        EWR.trackFiles[trackName] = {}
        EWR.trackFiles[trackName]["Name"] = trackName
        EWR.trackFiles[trackName]["Object"] = targets.object
        EWR.trackFiles[trackName]["LastDetected"] = timer.getAbsTime()
        if targets.object:getCategory() == 2 and targets.object:getDesc().guidance == 5 and IADSEWRARMDetection and not self:prevDetected(EWR, targets.object) then
          EWR.ARMDetected[targets.object:getName()] = targets.object
          for _, SAM in pairs(EWR.SAMsControlled) do
            if math.random(1,100) < EWRARMShutdownChance then
              self:magnumHide(SAM)
            end
          end
        end
        if targets.distance then
          EWR.trackFiles[trackName]["Position"] = targets.object:getPosition()
          EWR.trackFiles[trackName]["Velocity"] = targets.object:getVelocity()
        end
        if targets.type then
          EWR.trackFiles[trackName]["Category"] = targets.object:getCategory()
          EWR.trackFiles[trackName]["Type"] = targets.object:getTypeName()

        end
        if EWR.Datalink then
          EWR.trackFiles[trackName]["Datalink"] = true
        end
        TrackFiles["EWR"][trackName] = EWR.trackFiles[trackName]
      end
    end
  end
  return 2
end

function IADS:SAMTrackFileBuild()
  for _, SAM in pairs(SAMSites) do
    local detections = SAM.SAMGroup:getController():getDetectedTargets(Controller.Detection.RADAR)
    for _, targets in pairs(detections) do
      if targets.object and targets.object:inAir() then
        local trackName = targets.object.id_
        SAM.trackFiles[trackName] = {}
        SAM.trackFiles[trackName]["Name"] = trackName
        SAM.trackFiles[trackName]["Object"] = targets.object
        SAM.trackFiles[trackName]["LastDetected"] = timer.getAbsTime()
        if targets.object:getCategory() == 2 and targets.object:getDesc().guidance == 5 and IADSSAMARMDetection and not self:prevDetected(SAM, targets.object) then
          SAM.ARMDetected[targets.object:getName()] = targets.object
          if math.random(1,100) < SAMARMShutdownChance then
            self:magnumHide(SAM)
          end
        end
        if targets.distance then
          SAM.trackFiles[trackName]["Position"] = targets.object:getPosition()
          SAM.trackFiles[trackName]["Velocity"] = targets.object:getVelocity()
        end
        if targets.type then
          SAM.trackFiles[trackName]["Category"] = targets.object:getCategory()
          SAM.trackFiles[trackName]["Type"] = targets.object:getTypeName()
        end
        if SAM.Datalink then
          SAM.trackFiles[trackName]["Datalink"] = true
        end
        TrackFiles["SAM"][trackName] = SAM.trackFiles[trackName]
      end
    end
  end
  return 2
end

function IADS:AWACSTrackFileBuild()
  for _, AWACS in pairs(AWACSAircraft) do
    local detections = AWACS.AWACSGroup:getController():getDetectedTargets(Controller.Detection.RADAR)
    for _, targets in pairs(detections) do
      if targets.object and targets.object:inAir() then
        local trackName = targets.object.id_
        AWACS.trackFiles[trackName] = {}
        AWACS.trackFiles[trackName]["Name"] = trackName
        AWACS.trackFiles[trackName]["Object"] = targets.object
        AWACS.trackFiles[trackName]["LastDetected"] = timer.getAbsTime()
        if targets.distance then
          AWACS.trackFiles[trackName]["Position"] = targets.object:getPosition()
          AWACS.trackFiles[trackName]["Velocity"] = targets.object:getVelocity()
        end
        if targets.type then
          AWACS.trackFiles[trackName]["Category"] = targets.object:getCategory()
          AWACS.trackFiles[trackName]["Type"] = targets.object:getTypeName()
        end
        if AWACS.Datalink then
          AWACS.trackFiles[trackName]["Datalink"] = true
        end
        TrackFiles["AWACS"][trackName] = AWACS.trackFiles[trackName]
      end
    end
  end
  return 2
end

function IADS:EWRSAMOnRequest()
  for _, SAM in pairs(SAMSites) do
    if(tablelength(SAM.ControlledBy) > 0) then
      local viableTarget = false 
      for _, EWR in pairs(SAM.ControlledBy) do
        for _, target in pairs(EWR.trackFiles) do
          if target.Position and self:getDistance(SAM.Location, target.Object:getPoint()) < SAM.EngageRange then
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
  for _, SAM in pairs(SAMSites) do
    if SAM.Hidden then
      SAM.HiddenTime = SAM.HiddenTime - 2
      if SAM.HiddenTime < 1 then
        SAM.Hidden = false
      end
    end
  end
  return 2
end

function IADS:BlinkSAM()
  for _, SAM in pairs(SAMSites) do
    if tablelength(SAM.ControlledBy) < 1 then
      if SAM.BlinkTimer < 1  and (not SAM.Hidden) then
        if SAM.Enabled then
          self:disableSAM(SAM)
          SAM.BlinkTimer = math.random(30,60)
        else
          self:enableSAM(SAM)
          SAM.BlinkTimer = math.random(30,60)
        end
      else
      SAM.BlinkTimer = SAM.BlinkTimer - 2
      end
    end
  end
  return 2
end

function IADS:onDeath(event)
  if event.initiator:getCategory() == Object.Category.UNIT and event.initiator:getGroup() then
    local eventUnit = event.initiator  
    local eventGroup = event.initiator:getGroup()
    for _, SAM in pairs(SAMSites) do     
      if eventGroup:getName() == SAM.Name then
        if eventUnit:hasAttribute("SAM TR") then
          SAM.numSAMRadars = SAM.numSAMRadars - 1
        end  
        if SAM.numSAMRadars < 1 then
          for _, EWR in pairs(EWRSites) do           
            for _, SAMControlled in pairs(EWR.SAMsControlled) do 
              if SAMControlled.Name == SAM.Name then
                EWR.SAMsControlled[SAM.Name] = nil
              end              
            end          
          end
          SAMSites[SAM.Name] = nil
        end
      end
    end 
    for _, EWR in pairs(EWRSites) do    
      if eventGroup:getName() == EWR.Name then
        if eventUnit:hasAttribute("EWR") then
          EWR.numEWRRadars = EWR.numEWRRadars - 1
          if EWR.numEWRRadars < 1 then  
            for _, SAM in pairs(SAMSites) do              
              for _, controllingEWR in pairs(SAM.ControlledBy) do              
                if controllingEWR.Name == EWR.Name then 
                  SAM.ControlledBy[EWR.Name] = nil
                end              
              end            
            end
            EWRSites[EWR.Name] = nil              
          end
        end
      end
      for _, AWACS in pairs(AWACSAircraft) do    
        if eventGroup:getName() == EWR.Name then
          if eventUnit:hasAttribute("AWACS") then
            AWACS.numAWACS = AWACS.numAWACS - 1
            if AWACS.numAWACS < 1 then  
              AWACSAircraft[AWACS.Name] = nil              
            end
          end
        end
      end
    end   
  end   
end

function IADS:onShot(event)
  if IADSRadioDetection then
    if event.weapon then    
      local ordnance = event.weapon
      local WeaponPoint = ordnance:getPoint()
      local WeaponDesc = ordnance:getDesc()
      local init = event.initiator
      if WeaponDesc.guidance == 5 then      
        for _, SAM in pairs(SAMSites) do        
          if math.random(1,100) < IADSARMHidePctage and self:getDistance(SAM.Location, WeaponPoint) < IADSARMHideRangeRadio then          
            self:magnumHide(SAM)            
          end        
        end      
      end
    end 
  end
end

function IADS:onBirth(event)
  local isEWR = false
  local isSAM = false
  local isAWACS = false
  local hasDL = false
  local samType
  local numSAMRadars = 0
  local numTrackRadars = 0
  local numEWRRadars = 0
  local gp = event.initiator:getGroup()
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
      EWRSites[gp:getName()] = {
          ["Name"] = gp:getName(),
          ["EWRGroup"] = gp,
          ["SAMsControlled"] = {},
          ["Location"] = gp:getUnit(1):getPoint(),
          ["numEWRRadars"] = numEWRRadars,
          ["ARMDetected"] = {},
          ["Datalink"] = hasDL,
          ["trackFiles"] = {},
      }
      isEWR = false 
      isSAM = false
      numEWRRadars = 0
      numSAMRadars = 0
    elseif isSAM and self:rangeOfSAM(gp) then
      SAMSites[gp:getName()] = {
          ["Name"] = gp:getName(),
          ["SAMGroup"] = gp,
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
          ["trackFiles"] = {},           
      }
      isEWR = false  
      isSAM = false
      numEWRRadars = 0
      numSAMRadars = 0
    end
    self:associateSAMS() 
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
      AWACSAircraft[gp:getName()] = {
        ["Name"] = gp:getName(),
        ["AWACSGroup"] = gp,
        ["numAWACS"] = numAWACS,
        ["Datalink"] = hasDL,
        ["trackFiles"] = {},   
       }    
    end
  end  
end

function IADS:disableAllSAMs()
  for _, SAM in pairs(SAMSites) do
    SAM.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
    SAM.Enabled = false
  end
end

function IADS:populateLists()
  local isEWR = false
  local isSAM = false
  local isAWACS = false
  local hasDL = false
  local samType
  local numSAMRadars = 0
  local numTrackRadars = 0
  local numEWRRadars = 0
  for _, gp in pairs(coalition.getGroups(1)) do
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
        EWRSites[gp:getName()] = {
            ["Name"] = gp:getName(),
            ["EWRGroup"] = gp,
            ["SAMsControlled"] = {},
            ["Location"] = gp:getUnit(1):getPoint(),
            ["numEWRRadars"] = numEWRRadars,
            ["ARMDetected"] = {},
            ["Datalink"] = hasDL,
            ["trackFiles"] = {},
        }
        isEWR = false
        isSAM = false
        numEWRRadars = 0
        numSAMRadars = 0
      elseif isSAM and self:rangeOfSAM(gp) then
        SAMSites[gp:getName()] = {
            ["Name"] = gp:getName(),
            ["SAMGroup"] = gp,
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
            ["trackFiles"] = {},
        }
        isEWR = false
        isSAM = false
        numEWRRadars = 0
        numSAMRadars = 0
      end
      self:associateSAMS()
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
        AWACSAircraft[gp:getName()] = {
          ["Name"] = gp:getName(),
          ["AWACSGroup"] = gp,
          ["numAWACS"] = numAWACS,
          ["Datalink"] = hasDL,
          ["trackFiles"] = {},
         }
      end
    end
  end
end

function IADS:disableAllSAMs()

  for _, SAM in pairs(SAMSites) do
    local disableArray = {SAM.Name, nil, nil}
    SAM.SAMGroup:getController():setOption(AI.Option.Ground.id.ALARM_STATE,1)
    SAM.Enabled = false
  end
end

function IADS:monitorTracks()

  for _, EWR in pairs(EWRSites) do  
    for _, track in pairs(EWR.trackFiles) do   
      if ((timer.getAbsTime() - track.LastDetected) > trackMemory or (not track.Object:isExist()) or (not track.Object:inAir())) then      
        EWR.trackFiles[track.Name] = nil 
        TrackFiles.EWR[track.Name] = nil     
      end   
    end  
  end 
  for _, SAM in pairs(SAMSites) do  
    for _, track in pairs(SAM.trackFiles) do    
      if ((timer.getAbsTime() - track.LastDetected) > trackMemory or (not track.Object:isExist()) or (not track.Object:inAir())) then      
        SAM.trackFiles[track.Name] = nil
        TrackFiles.SAM[track.Name] = nil      
      end   
    end  
  end
  for _, AWACS in pairs(AWACSAircraft) do
    for _, track in pairs(AWACS.trackFiles) do
      if ((timer.getAbsTime() - track.LastDetected) > trackMemory or (not track.Object:isExist()) or (not track.Object:inAir())) then
      AWACS.trackFiles[track.Name] = nil 
        TrackFiles.AWACS[track.Name] = nil     
      end   
    end  
  end       
--  if tablelength(TrackFiles) ~= 0 then
--   env.info(table.tostring(TrackFiles))    
--  end
end

function IADS:sysIADSEventHandler(event)
  local relevents = {
    [world.event.S_EVENT_DEAD]                = self.onDeath,
    [world.event.S_EVENT_SHOT]                = self.onShot,
    [world.event.S_EVENT_BIRTH]               = self.onBirth,
  }
  if relevents[event.id] == nil then
    Logger:debug("sysTicketsEventHandler - not relevent event: "..
      tostring(event.id))
    return
  end
  relevents[event.id](self, event)
end


function IADS:__init(theater)
  assert(theater ~= nil, "value error: theater must be a non-nil value")
  Logger:debug("init system.IADS event handler")
  self.theater = theater
  theater:registerHandler(self.sysIADSEventHandler, self)
  if IADSEnable then
    theater:queueCommand(10, Command(self.populateLists, self))
    theater:queueCommand(10, Command(self.EWRTrackFileBuild, self))
    theater:queueCommand(10, Command(self.SAMTrackFileBuild, self))
    theater:queueCommand(10, Command(self.AWACSTrackFileBuild, self))
    theater:queueCommand(10, Command(self.monitorTracks, self))
    theater:queueCommand(10, Command(self.SAMCheckHidden, self))
    theater:queueCommand(10, Command(self.BlinkSAM, self))
  end
end

return IADS
