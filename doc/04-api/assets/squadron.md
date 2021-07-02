# Squadron

A logical representation of a group of aircraft associated with a given
airbase.

## Template Definition

Example template definition.

**file location:** `<theater-root>/Region 1/99thfs.dct`

```lua
objtype = "squadronplayer"
name = "99thFS"
coalition = 2
intel = 2
ato = {"CAP", "cas"}
payloadlimits = {
	["ag"] = 20,
	["aa"] = 5,
}
```

### AI Squadrons

An STM file is associated with an AI squadron which defines various
things including:

 * airplane type
 * payload
 * mission type

The first helicopter or airplane group found in the STM will define the
aircraft used for the squadron. The first unit in the remaining groups
will define additional payloads the squadron is capable of carrying.
The mission "task" type defined for the group will limit the payload to
only be used for the equivalent DCT mission type, seen in table 1. The
first group's payload will be used if there is not a more specific
payload defined.

**(Table 1) Mission Editor Task Types:**

 - Nothing
 - AFAC
 - Anti-ship Strike (ASUW)
 - AWACS
 - CAP
 - CAS
 - Escort
 - Fighter Sweep
 - Ground Attack
 - Intercept
 - Pinpoint Strike
 - Reconnaissance
 - Refueling
 - Runway Attack
 - SEAD
 - Transport

### Player Squadrons

Player squadrons do not need an STM file and have a few limitations:

 * Player slots cannot be mixed with an AI squadron
 * a slot can belong to one and only one squadron

A player slot can specify squadron membership by making the **first
word of the group name** equal to any squadron template name defined
in the theater definition. If the squadron does not exist when
a player spawns into the slot defaults for payloadlimits and ato
will be used.

## Details

### Disablement and Death

Conditions which a squadron is no longer able to sortie missions.

Disable Conditions:

 1. Depleting airframe count
 2. Airbase is not operational

Death Conditions:

 1. Capturing the airbase

### Create Flights from Mission Requests

TODO
