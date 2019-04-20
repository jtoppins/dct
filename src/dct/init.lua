--[[
Top level initialization and kickoff package

----
init function initializes game state

----
start/run function starts the DCT engine

]]--
--require("os")

local template = require("dct.template")
local libs = require("libs")

require("math")

local init = {}
function init.init (dctsettings)

  --Parse the dctsettings and act on them
  
  --Check to see if there's a game state
  --If yes, load it
  --If no, generate a new one and save it out
  
  --No state is found, generate the new state by iterating over all the templates
  local templatePath = lfs.writedir() .. "DctTemplates\\PhaseOne\\"
  local missionRegionsFilePath = lfs.writedir() .. "DctTemplates\\PhaseOne\\regions.lua"
  local regions = {}
    
  init.getRegions(missionRegionsPath, regions)
  init.getTemplates(templatePath, regions)
  init.spawnRegionalContent(regions)
  
  --templates[t.name] = t
  --Call some function that kicks off the campaign engine
  --init.testSpawn()
  return true
end

function init.getRegions (regionsFilePath, regions)
  rc = pcall(dofile, regionsFilePath)
  assert(rc, "failed to parse: " .. regionsFilePath)
  assert(mission_regions ~= nil)
  regions = mission_regions
  mission_regions = nil
  return true
end

function init.getTemplates (templatePath, regions)
  for file in lfs.dir(templatePath) do
    if file ~= "." and file ~= ".." then
      local f = templatePath.."/"..file
      local attr = lfs.attributes(f)
      if attr.mode == "directory" then
        init.getTemplates(f, templates)
      else
        if string.find(f, ".stm") ~= nil then
          local dctString = string.gsub(f, ".stm", ".dct")
          local t = template.Template(f, dctString)
          regions[t.region]["templates"][t.type][t.name] = t
        end
      end
    end
  end
  return true
end

function init.spawnRegionalContent(regions)
  for regionKey, regionData in pairs(regions)
    --Iterate over the types 
    for typeKey, typeData in pairs(regionData["spawninfo"])
      init.SpawnTemplates(regionData["templates"][typeKey], typeData["min"], typeData["max"])
  end
  return true
end


function init.SpawnTemplates(templates,spawnMin,spawnMax)
  local i = 0
  local spawnNum = math.random(spawnMin, spawnMax)
  for templateKey, templateData in pairs(templates)
    templateData:spawn()
    i = i+1
    if i >= spawnNum then
      break
    end
  end
  return true
end

function init.testSpawn ()
  local stmFile = lfs.writedir() .. "DctTemplates\\test.stm"
  local dctFile = lfs.writedir() .. "DctTemplates\\test.dct"
  local t = template.Template(stmFile, dctFile)
  t:spawn()
  return true
end
return init