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


## Mission UI

F10 menu for player requested/assigned missions. This describes the menus and
states associated with a player group and the mission menu.

### Menus

#### Intel Menu

	F1. Intel Maps
		F1. Strategic
		F2. Air Defense
		F3. Display Target
		F4. Clear All

#### No Assigned Mission

	F2. Mission
		F1. Request
		F2. Join

#### Mission Assigned

	F2. Mission
		F1. Briefing
		F2. Status
		F3. Rolex +30
		F4. Abort
		FX. <mission specific>

### Commands

#### Intel Maps

Display various intel on the F10 map via DCS mark points. Follow a few simple
rules.

 1. use the mark system to provide a visual intel report at both the
    strategic region and air defense levels
 2. do not force the visuals on players, have them request to see it
 3. Allow the marks to be deleted by the players

##### Strategic

Display per-region strategic information like;

 * if there is a sam threat in the region
 * if there are shorad in the region
 * any cap threat in the area

##### Air Defense

Display SAM threats (not shorad) with the marks representing their approximate
location based on the intel level currently known about the SAM.

#### Mission

Provides the submenu

##### Request

Request a mission of the requested type. There are no restrictions to when a
player can request a mission other than when one is already assigned.

#### Join

The player uses the scratchpad to join a mission already in existance. Joining
should check if the joining player's airframe is allowed fly the type of
mission being joined.

#### Briefing

Contents of a briefing:

 * Mission/Package ID - used by other players to join mission
 * Target (location, codename, and short description)
 * Transponder Codes (M1, M2, M3) - specific to the aircraft in order of
     when they joined the mission, max 6 players can join a mission
 * Release Time - time at which you are able to takeoff
 * Void Time - time by which you should have taken off
 * TOS/TOT - time by which you should checkin/hit your target
 * <Mission Specific Items>
     Examples: JTAC frequency
 * Expanded Mission Briefing

Falcon 4.0 BMS has the following briefing sections:

	 * Overview (pgk#, short description, station area, TOS/TOS)
	 * Situation (describes the larger situation in the region)
	 * Pilot Roster (not important)
	 * Package Elements (not important)
	 * Threat Analysis (A2A & SAM)
	 * Steerpoints (not important)
	 * Comms Ladder (maybe?)
	 * IFF (some of it)
	 * Ordnance (not important)
	 * Weather (possibly)
	 * Support (possibly)
	 * ROE (possibly)
	 * Emergency Procedures (possibly)

#### Status

Updates the player on the status of the mission.

#### Rolex +30

Pushes the timeout of the mission by 30 minutes.

#### Abort

Aborting only aborts for the requestor, once all members of a mission have
aborted the mission it is then retired.

