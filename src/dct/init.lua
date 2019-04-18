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

	--No state is found, generate the new state by iterating over all the templates
	local templatePath = lfs.writedir() .. "DctTemplates\\"
	local templates = {}

	--init.getTemplates(templatePath, templates)

	--templates[t.name] = t
	--Call some function that kicks off the campaign engine
	init.testSpawn()
	return true
end

function init.getTemplates (templatePath, templates)
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
					templates[t.name] = t
					t:spawn()
				end
			end
		end
	end
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
