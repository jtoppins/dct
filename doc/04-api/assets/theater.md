# Theater Configuration

Theater level configuration consist of various files that manipulate a
specific aspect of DCT on a theater wide level.

## `theater.goals`

Defines per-side win conditions. Once these conditions are for any given
side the campaign terminates.

Types of conditions:

 * number of pilots lost
 * percentage of assets destroyed, including sub-classes
 * time limit

## `restrictedweapons.cfg`

dct.settings.restrictions:

	- stores various restrictions

dct.settings.restrictions.weapons:

 - stores the weapons restriction table that defines the cost of a weapon
   for players

Example:

	restrictedweapons = {
		["<wpntype>"] = {
			cost = #,
			category = "aa|ag",
		},
	}

## `payloadlimits.cfg`

dct.settings.restrictions.payloads:

 - defines the per-airframe cost limits for classes of weapons

Example:

	payloadlimits = {
		{
			actype = "default",
			ag = 20,
			aa = 20,
		},
	}

## `codenamedb.cfg`

dct.settings.codenamedb

	codenamedb = {
		["<asset-type-name>"] = <name-list>,
		...
		["default"] = <name-list>,
	}

## `payloads` directory

dct.settings.payloads

 **do not have payloads broken out, instead allow payloads be
   defined in the stm file.**
