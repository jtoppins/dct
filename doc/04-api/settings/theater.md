# Theater Configuration

Theater level configuration consist of various files that manipulate a
specific aspect of DCT on a theater wide level.

## Theater Goals

Theater goals define the way in which DCT will evaluate the completion
of the campaign. It is a simple ticket system much like what is present
in many AAA FPS titles.

### Example

**file location:** `<theater-root>/theater.goals`

	time = 43200  -- 12 hours in seconds
	blue = {
		flag            = 45,
		tickets         = 100,
		player-cost     = 1,
		modifier-reward = 0.5,
		modifier-loss   = 0.2,
	}

	neutral = {
		flag    = 20,
		tickets = 0,
	}

	red = {
		flag       = 60,
		tickets    = 200,
		difficulty = "easy",
	}

### Configuration Options

#### `time`

The total time, in seconds, the campaign will run before a winner is
determined and a new state is generated. Set to zero to disable the
timer.

#### `red`, `blue` and `neutral`

Each faction definition is required and can have the following
possible entries;

##### `flag`

 * required

Defines the flag number used in the associated .miz which will trigger
an end of the mission.

DCT relies on the associated mission to provide 3 triggers (one per
faction), with each trigger being conditional on the specified flag
number being true. With the action of the trigger being the mission-end
action with the values of the mission end action representing a winning
condition. This means that the flag for the red faction, if set to true,
will result in a mission end event stating the red team has won.

##### `tickets`

 * required

Number of tickets the side's ticket pool starts with. The Neutral
faction can start with zero tickets all others must have above zero.

Ticket loss and reward:

Tickets are lost by the owning side each time an asset dies. A side may
gain tickets for completing missions. The calculations are as follows:

	tickets-lost = asset.cost * owner.modifier-loss

	tickets-gained = tgtasset.cost * mission.owner.modifier-reward

An example; suppose a flight of two players (blue) attacked and destroyed
a factory (red) which was part of their mission. During the mission one
of the players is shot down.

Point values and modifiers:

 * factory worth 10 tickets
 * player cost worth 2 tickets
 * red modifiers; ticket = 50, modifier-reward = .5, modifier-loss = .5
 * blue modifiers; tickets = 30, modifier-reward = 1, modifier-loss = 1

Red Tickets:

	red tickets = 50 - (factory.cost * red.modifier-loss)
	            = 50 - (10 * .5)
	            = 45

Blue Tickets:

	blue tickets = 30 - (player.cost * blue.modifier-loss) + mission success
	             = 30 - (2 * 1) + mission success
	             = 28 + (factory.cost * blue.modifier-reward)
	             = 28 + (10 * 1)
	             = 38

Therefore even though blue lost a plane they were able to net 8 tickets.
While red lost a net of 5 tickets. It is up to the campaign designer to
assign costs to each asset, via their .dct file.

##### `difficulty`

 * _default:_ `custom`
 * _value:_ limit set of strings (`easy`, `normal`, `hard`, `realistic`,
  `custom`)

Defines some predefined settings for player-cost, modifier-reward, and
modifier-loss. If this is set to anything other than `custom` any
explicitly defined values for player-cost, etc will be overwritten.

`easy`:

 * player-cost: 1
 * modifier-reward: .5
 * modifier-loss: 1.5

`normal`:

 * player-cost: 1
 * modifier-reward: 1
 * modifier-loss: 1

`hard`:

 * player-cost: 1
 * modifier-reward: 1.5
 * modifier-loss: .5

`realistic`:

 * player-cost: 1
 * modifier-reward: 1
 * modifier-loss: 0

##### `player-cost`

Defines the cost of each player slot.

##### `modifier-reward`

Defines the multiplicative modifier that is applied to all rewards the
given faction receives.

##### `modifier-loss`

Defines the multiplicative modifier that is applied to all losses the
given faction takes.

## Defined Weapon Categories

These categories are used in the payload limits and restricted weapons
definitions.

 * `AG` - air-to-ground weapons category
 * `AA` - air-to-air weapons category

These identifiers are case insensitive.

## Payload Limits

The payload limits configuration allows a campaign designer to define a
default limit for each weapon category. This default, if defined, will
be applied for all player aircraft regardless of side.

A hardcoded default table is built into DCT which allows a limit of
4999 per category. There is an infinite weapons cost hardcoded to
5000, setting any weapon cost to this value will deny the use of that
weapon in the mission.

### Example

**file location:** `<theater-root>/settings/payloadlimits.cfg`

	ag = 20
	aa = 20

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

	facility = {"FORD", "DODGE", "CHEVY",}
	sam = {"alpha", "bravo", "charlie",}

The above example will override the name list of "C2" assets with the
list of possible names above.

### Internal API

**table access:** `_G.dct.settings.codenamedb`

 - stores the codename database

## User Interface(UI)

Allows the mission designer to modify various defaults about the
DCT UI.

`gridfmt`:

DCT formats user facing coordinates based on the type of aircraft
they are flying. This table allows the mission designer to modify
the coordinate format which the player will see. The default format
is degrees minutes seconds(DMS), this means if the aircraft should
see a coordinate in DMS then it does not need to be in the table.
Also, DCT provides generally reasonable defaults for most flyable
aircraft. This grid format setting applies to the aircraft specified
regardless of side.

Valid Grid Formats (case insensitive):

 * `dms` - degrees minutes seconds decimal (45° 32' 30.04")
 * `mgrs` - military grid reference system (NY 1234567890)
 * `dd` - degrees decimal (45.534°)
 * `ddm` - degrees decimal minutes (45° 32.501')

`ato`:

By default DCT allows all possible mission types to be requested
by the player. If the mission designer chooses to limit the types
of missions a specific airframe can fly this is where they do it.
The designer must specify *all* mission types a given airframe is
allowed to request. This per-airframe setting applies to all
airframes of the type regardless of side.

List of Valid Mission Types (case insensitive):

 * `cap` - combat air patrol
 * `cas` - close air support
 * `strike` - strike mission
 * `sead` - suppression of enemy air defense
 * `bai` - battlefield air interdiction (currently not implemented)
 * `oca` - offensive counter air
 * `armedrecon` - armed reconnaissance

### Example

**file location:** `<theater-root>/settings/ui.cfg`

	gridfmt = {
		["UH-1H"] = "ddm",
	}
	ato = {
		["UH-1H"] = {"armedrecon", },
	}

### Internal API

**table access:** `_G.dct.settings.ui`
