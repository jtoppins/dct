# Missions

A mission is a logical grouping of a target, assigned asset(s), and a set of
goals that must be accomplished to achieve mission success. Missions are
assigned to both player and AI groups.

## States

There are 5 possible states a mission can be in.

### scheduled

Scheduled missions have a target and set of goals but no group assigned to
execute the mission. These missions have a timeout period and can expire
if the mission goals can no longer be completed.

Transitions:

 * _to active:_ on first assigned group
 * _to scrubbed:_ when timeout or target dead

### active

Active missions have an assigned group executing the mission. Once a mission
goes active other players will have 30 minutes to join the mission before
it is considered locked.

 - active missions will be automatically terminated once all players are
   no longer part of the mission or the timeout expires
 - yes do slot blocking of player slots if the airbase the slot is at
   does not belong to the side the slot is for

Transitions:

 * _to success:_ mission goals met
 * _to aborted:_ none assigned

### scrubbed

Terminal state, mission is reclaimed

### aborted

Terminal state, mission is reclaimed

### success

Terminal state, mission is reclaimed
