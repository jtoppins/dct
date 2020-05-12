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
