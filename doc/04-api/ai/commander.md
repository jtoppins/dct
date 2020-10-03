# AI Commander

The strategic AI commander per side.

Responsible for:
 * _strategic planning_
 * _mission planning & scheduling_
 * _theater analysis_



Enemy AI will be grouped into 'squadrons' with some squadrons existing on-map
and some off-map.

Squadrons will have the following attributes:
	* home airbase or spawn location if no airbase
	* squadron size or unlimited
	* moral
	* type of aircraft flown, each squadron flies only a single airframe
	* payload definition
	* destroyed state description; if any of the states become true
		the squadron becomes destroyed.

Priority Sort Order

sorting order used to sort targets

critera to consider:
- distance to target - not sure distance should matter
- priority of target


Q: How should selection work?
A: Selection of a target should be based on the "priority" of that target and its
   relative threat level compared to the


(regionprio + (-10*ismissionassigned) + assigned)*65536 + tgtprio


## Region & Theater Threat Reports

 * SEA
 * AIR
 * ELINT
 * SAM
 * SHORAD

Measure these items based on a threat point system. The threat reported
is only for the assets detected, this can mean threats not detected
will not be reported or the threat be under reported.

For example the threat calculation for SAMs would be:

    threat = sum(SAM.threat, 0, i)

For calculation of air threat the calculation would be:

    threat = sum(AIR.enemy.threat,0,i) - sum(AIR.friendly.threat,0,x)

This means we do not need to know how many assets were originally
spawned. Making it easier to dynamically figure out threats without
having to keep individual counts of everything all the time.

The region threat for each item can be periodically calculated along
with the commander's theater view.

Note: the threat for each asset will need to be a 3 tuple to cover
air, land, and sea threat capability of the asset.


## Mission Assignment

# mission assignment: assign missions based on a region

## Summary

Given 5 regions choose the highest priority region. Select missions from this region until a fixed maximum number of missions are assigned.

 * What triggers a reselection?
   - on mission limit reached
 * What happens if there are no more assets of the type requested in the active region?
   - the next region in priority order should be looked at
 * How does the reselection keep from selecting the currently "full" region?

Upon reselection of a new region

 question, starting the design of the new mission assignment system. When a player requests a mission what should happen? A scenario; The current active region is islands and a CAP mission is already assigned to islands (thus CAP is full for islands). A new player requests CAP, what should happen?

Currently the next CAP station would be assigned in the list until there are no more possible CAP stations. This is actually the case for all mission types.

What I understood from past discussions, is it seems like the new CAP player should get the message of "no CAP missions available". Would this be correct?

Or should a hybrid based on the number of players scale the available mission slots. In this case should the jask region be selected for the CAP assignment, if there are 15+ players on the server. Even if the maximum number of missions in islands has not been reached?

Another alternative, should certain mission types be allowed to "spill-over" into other regions, thus "unlocking" the region for other mission types. For example; at the beginning of a new server, should only SEAD and CAP missions be assignable until until the strategic SAMs are taken out in islands? Then CAP and SEAD can be assigned in jask (assuming it was next) but no strike targets in jask until the SAM is taken out.

Final alternative, should current active missions influence what is assigned next and what happens when there is available mission of the requested type?


# Mission Tasking

 and mission tasking being support more than just determining if an asset is dead or not allow different types of taskings have different goal criteria. For example a CAP tasking would be based on station time

mission tasking is supporting other types of missions beyond "go blow something up"  like "go hang-out here for a while and kill aircraft/tanks" or "transport box-x to position y" or many other types of taskings.
