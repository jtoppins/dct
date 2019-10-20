require("os")

test = {}
function test.debug(str)
	if os.getenv("DCT_DEBUG") then
		print("DEBUG: " .. str)
	end
end

check = {}
check.spawngroups  = 0
check.spawnstatics = 0
