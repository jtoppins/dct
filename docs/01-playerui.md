# Players

This section describes the custom UI players can interact with.

## F10 Menus

Players interact with the theater through the "F10. Other" radio menu.

### Scratchpad Menu

The player scratchpad allows a player to input arbitrary data into the game.
This allows for things like submitting intel reports, joining another person's
mission, etc.

	F1. Scratch Pad
		F1. DISPLAY
		F2. SET
		F3. RUN


#### DISPLAY

Displays the contents of the current value of the scratch pad.

#### SET

Sets the value of the scratch pad by putting a mark on the map. The mark
will be placed at the current position of the player's aircraft. It is then
expected the player will edit this mark in the F10 map, the text script
put in the body of this map marker will become the new value of the scratch
pad.

**Note:** The moment focus is changed from this mark the scratch pad value will
be stored and the mark deleted from the map. Thus one cannot expect to go
in and out of the F10 map to edit the mark.

#### RUN

Run a generic text based command from the user.

### Intel Menu

	F2. Intel Maps
		F1. Strategic
		F2. Air Defense
		F3. Display Target
		F4. Clear All


These options display various intel on the F10 map via DCS mark points.
The maps are intended to provide the following:

 1. use the mark system to provide a visual intel report at both the
    strategic region and air defense levels
 2. do not force the visuals on players, have them request to see it
 3. Allow the marks to be deleted by the players

#### Strategic

Displays per-region strategic threat information, the categories are:

 * _AIR_ - any historical or current air threats in the region
 * _SAM_ - any **S**urface to **A**ir **M**issile systems in the region and
           types
 * _SHORAD_ - any short range or low level air defense in the region
 * _SEA_ - any sea threats known to be in the region

Example map mark report:

	Title: Region <name> Threat Report
	Body:
		AIR: Low
		SAM: High; 2 x SA-6, 1 x SA-10
		SHORAD: Medium
		SEA: None


#### Air Defense

Display SAM threats (not SHORAD) with marks representing their approximate
location based on the intel level currently known about the SAM.

Example map mark report:

	Title: SAM SA-6
	Body: empty


#### Display Target

Creates a mark point displaying the location of the assigned target location.

Example map mark report:

	Title: Target <callsign>
	Body:
		Location: <coords, airframe specific>
		Threat Report:
			AIR: Low
			SAM: High; 2 x SA-6, 1 x SA-10
			SHORAD: Medium
			SEA: None
		Weather:
			METAR: <time> <wind> <clouds> <temps> <altimiter>


#### Clear All

Clears all marks made by the system for the player.


### Ground Crew Menu

	F3. Ground Crew
		F1. Check Payload
		F2. Carrier Status

#### Check Payload

If enabled provides a way for the player to verify that their payload is valid.

#### Carrier Status

Check what the status of the carrier is and if you can recover at the carrier.

### Mission Menu

F10 menu for player requested/assigned missions.

#### No Assigned Mission

	F4. Mission
		F1. Request
			F1. <allowed-mission-type-1>
			...
			FN. <allowed-mission-type-8>
		F2. Join


##### Request

Request a mission of the requested type. There are no restrictions to when a
player can request a mission other than when one is already assigned.

##### Join

Uses the scratchpad to join a mission already in existance. The system
will verify the joining player's airframe is allowed fly the type of
mission being joined.


#### Mission Assigned

	F4. Mission
		F1. Briefing
		F2. Status
		F3. Rolex +30
		F4. Abort
		FX. <mission specific>


##### Briefing

Gets the briefing associated with the assigned mission.
Briefing contents:

 * _Overview_ - pkg#, short description, target information
   - _Package ID_ - players can use this to join the mission
   - _Target_ - location and codename
 * _Description_ - summary text
 * _IFF_ - M1 &  M3 codes specific to the aircraft in order of when they
           joined the mission, max 6 players can join a mission
 * _Threat Analysis_ - same analysis report provided in the strategic map
 * _Remarks_ - any additional mission specific information

Example briefing:

	### Overview
	Package: #5720
	Target: 88°07.2'N 063°27.6'W (PHOENIX)

	### Description
	Ground units operating in the area have informed us of an Iranian
	Ammo Dump 88°07.2'N 063°27.6'W. Find and destroy the bunkers and
	the ordnance within.
	    Tot: 2001-06-22 12:02z

	    Primary Objectives: Destroy the large, armoured bunker. It is
	heavily fortified, so accuracy is key.

	    Secondary Objectives: Destroy the two smaller, white hangars.

	    Recommended Pilots: 2

	    Recommended Ordnance: Heavy ordnance required for bunker targets,
	e.g. Mk-84s or PGM Variants.

	### IFF
	M1(05), M3(5720)

	### Threat Analysis
	<same threat analysis used in strategic map>

	### Remarks
	None


##### Status

Updates the player on the status of the mission.

	Package: 5720
	Timeout: 2001-06-22 14:03z (in 297 mins)
	BDA: 0% complete


##### Rolex +30

Pushes the timeout of the mission by 30 minutes.

##### Abort

Aborting only aborts for the requestor, once all members of a mission have
aborted the mission it is then retired.
