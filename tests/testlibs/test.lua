require("os")

test = {}
function test.debug(str)
	if os.getenv("DCT_DEBUG") then
		print("DEBUG: " .. str)
	end
end
