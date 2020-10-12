# Theater Configuration

Theater level configuration consist of various files that manipulate a
specific aspect of DCT on a theater wide level.

## Theater Goals

	Currently not implemented

## Defined Weapon Categories

These categories are used in the payload limits and restricted weapons
definitions.

 * `AG` - air-to-ground weapons category
 * `AA` - air-to-air weapons category

These identifiers are case insensitive.

## Payload Limits

The payload limits configuration allows a campaign designer to define a
default limit for each weapon category. This default if defined will be
applied for all player aircraft regardless of side.

A hardcoded default table is built into DCT which allows a limit of
4999 per category. There is an infinite weapons cost hardcoded to
5000, setting any weapon cost to this value will deny the use of that
weapon in the mission.

### Example

**file location:** `<theater-root>/settings/payloadlimits.cfg`

	payloadlimits = {
		["ag"] = 20,
		["aa"] = 20,
	}

### Internal API

**table access:** `_G.dct.settings.payloadslimits`

 - the location where the default payload limits table can be accessed

## Restricted Weapons

The restricted weapons configuration allows a campaign designer to limit
or remove the use of a given weapon type without the need to modify the
.miz. This allows for a consistent enforcement of restricted weapons
without having to update their mission each time the game adds a new
weapon.

The enforcement policy is one of removing the player from their slot
if they takeoff with a restricted loadout.

### Example

**file location:** `<theater-root>/settings/restrictedweapons.cfg`

	restrictedweapons = {
		["AIM-120C"] = {
			cost = 3,
			category = "aa",
		},
		["GBU-12"] = {
			cost = 15,
			category = "ag",
		},
	}

### Details

The algorithm is simple, weapons in the restricted list will apply their
defined cost value for each instance of the weapon loaded on the unit to
the category specified. This total value per category is then compared
to the defined limit per category, if the total is greater than the limit
the enforcement policy action is taken.

### Internal API

**table access:** `_G.dct.settings.restrictedweapons`

 - stores the weapons restriction table that defines the cost of each
   weapon

## Code Name Overriding

DCT assigns 'code names' to assets that are later used when players
request missions. This allows a campaign designer to override DCT's
default naming tables.

The codenamedb is a lua table with keys equal to the asset type value
and values equal to a name list.

### Example

**file location:** `<theater-root>/settings/codenamedb.cfg`


	codenamedb = {
		[4] = {"FORD", "DODGE", "CHEVY",},
	}

The above example will override the name list of "C2" assets with the
list of possible names above.

### Internal API

**table access:** `_G.dct.settings.codenamedb`

 - stores the codename database
