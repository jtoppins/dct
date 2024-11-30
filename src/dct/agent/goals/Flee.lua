-- SPDX-License-Identifier: LGPL-3.0

require("libs")
local class = libs.classnamed
local WS = require("dct.agent.worldstate")

--- Have an agent "flee".
-- @classmod Flee
local Flee = class("Flee", WS.Goal)
function Flee:__init()
	WS.Goal.__init(self, WS.WorldState({
			WS.Property(WS.ID.STANCE, WS.Stances.FLEEING),
		}))
end

-- TODO: how does a Flee goal increase in importance?
--
-- For SAM/EWR when anti-radiation missiles are launched at the site
-- there is a chance the site will flee/hide. This can be based on
-- the a probability distribution function. Also, if the SAM has
-- no targets and it doesn't have a search goal we want to
-- prefer this goal.
--
-- For a fighter flee selection might be based on number of enemy
-- fighters.
--
-- For attackers and supports(tankers, awacs) flee would be based
-- on how close enemy fighters are getting combined with if there
-- are friendly fighters in the area.
--
-- This could all be summariezed with a "threat" number, as the
-- number increases so does the utility of this goal.

return Flee
