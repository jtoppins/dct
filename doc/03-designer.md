# Campaign Designer

## Overview

## Theater

== Mission Template Directory Format

DCT relies on content that can be built directly in the mission editor, these
individuals need little to no programming stills to provide content to a DCT
enabled mission.

The directory hierarchy is:

    + <Mission Template Directory>
      - theater.goals
      + <Region Directory 1>
        - region.def
        + [bases]
        + [facilities]
        + [missions]
      + <Region Directory N>
        - region.def
        + [bases]
        + [facilities]
        + [missions]

## Regions

## The Template

[ui] aircraft grid format
[ui] codename database
[sys] ato mission type restrictions per airframe per side

configuration options:
- airframe specifications
  * allowed missions
  * coordinate format
  * payload limits
- codenamedb

## Configuration

### Airframe

Restrictions file:

	restrictions = {
		{
			["actype"]   = "F-15C",
			["side"]     = "red|blue|neutral|all",
			["missions"] = { "cap", "oca" },
			["gridfmt"]  = "ddm",
			["payload"]  = {
				["ag"] = 20,
				["aa"] = 10,
			},
		},
	}


Defaults:
 - grid format: dms
 - missions: any
 - payload: no limits

dct.settings.restrictions:
	- stores various restrictions

dct.settings.restrictions.weapons:
	- stores the weapons restriction table that defines the cost of a weapon
	  for players

dct.settings.restrictions.payloads:
	- defines the per-airframe cost limits for classes of weapons

restrictedweapons.cfg:
restrictedweapons = {
	["<wpntype>"] = {
		cost = #,
		category = "aa|ag",
	},
}

payloadlimits.cfg:
payloadlimits = {
	{
		actype = "default",
		ag = 20,
		aa = 20,
	},
}
