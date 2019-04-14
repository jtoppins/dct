--[[
Top level initialization and kickoff package

----
init function initializes game state

----
start/run function starts the DCT engine

]]--
--require("os")

local template = require("dct.template")

local init = {}
function init.init (dctsettings)

  --Parse the dctsettings and act on them
  
  --Check to see if there's a game state
  --If yes, load it
  --If no, generate a new one and save it out
  
  --Call some function that kicks off the campaign engine
  init.testSpawn()
  return true
end

function init.testSpawn ()
  local stmFile = lfs.writedir() .. "DctTemplates\\test.stm"
  local dctfile = lfs.writedir() .. "DctTemplates\\test.dct"
  
  local t = template.Template(stmFile, dctFile)
  t:spawn()
  return true
end
return init